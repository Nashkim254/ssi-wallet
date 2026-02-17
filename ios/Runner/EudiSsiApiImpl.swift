import EudiWalletKit
import Flutter
import Foundation
import MdocDataModel18013
import MdocDataTransfer18013
import Security
import WalletStorage

/// Production EUDI Wallet implementation for iOS
/// Uses the official EudiWalletKit SDK with OpenID4VCI/VP support
class EudiSsiApiImpl: NSObject, SsiApi {

    // Storage for DIDs and interactions (credentials managed by SDK)
    private var dids: [DidDto] = []
    private var interactions: [InteractionDto] = []

    // Storage for pending presentation sessions
    private var pendingSessions: [String: PresentationSession] = [:]

    // EUDI Wallet instance (will be initialized with real SDK)
    private var wallet: Any?  // Type will be: EudiWallet once SDK is imported
    private var isInitialized = false

    // MARK: - Initialization

    func initialize(completion: @escaping (Result<OperationResult, Error>) -> Void) {
        Task {
            do {
                print("[EudiSsiApiImpl] Initializing EUDI Wallet SDK...")

                let config = OpenId4VciConfiguration(
                    credentialIssuerURL: "https://issuer.eudiw.dev",
                    clientId: "wallet-dev",
                    authFlowRedirectionURI: URL(string: "eudi-openid4ci://authorize")!
                )

                // Load EUDI IACA trusted reader certificates from bundle
                let certNames = [
                    "pidissuerca02_ut", "pidissuerca02_eu", "pidissuerca02_cz",
                    "pidissuerca02_ee", "pidissuerca02_lu", "pidissuerca02_nl",
                    "pidissuerca02_pt", "r45_staging"
                ]
                var trustedCerts: [Data] = []
                for name in certNames {
                    if let url = Bundle.main.url(forResource: name, withExtension: "der"),
                       let data = try? Data(contentsOf: url) {
                        trustedCerts.append(data)
                        print("[EudiSsiApiImpl] Loaded trusted cert: \(name).der (\(data.count) bytes)")
                    }
                }
                print("[EudiSsiApiImpl] Loaded \(trustedCerts.count) trusted reader certificates")

                let wallet = try EudiWallet(
                    serviceName: "com.example.ssi.eudi.wallet",
                    trustedReaderCertificates: trustedCerts,
                    userAuthenticationRequired: false,
                    openID4VciConfigurations: ["issuer": config]
                )

                self.wallet = wallet
                self.isInitialized = true

                let result = OperationResult(
                    success: true,
                    error: nil,
                    data: [
                        "initialized": true,
                        "version": "EUDI iOS SDK v0.19.4",
                        "storage": "iOS Secure Storage",
                    ]
                )

                completion(.success(result))
            } catch {
                print("[EudiSsiApiImpl] Initialization failed: \(error)")
                let result = OperationResult(
                    success: false,
                    error: "Initialization failed: \(error.localizedDescription)",
                    data: nil
                )
                completion(.success(result))
            }
        }
    }

    func getVersion() throws -> String {
        return "EUDI Wallet iOS SDK v0.19.4 (integration pending)"
    }

    // MARK: - DID Management

    func createDid(
        method: String, keyType: String, completion: @escaping (Result<DidDto?, Error>) -> Void
    ) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print(
                    "[EudiSsiApiImpl] createDid() called with method: \(method), keyType: \(keyType)"
                )

                guard isInitialized, let wallet = wallet as? EudiWallet else {
                    print("[EudiSsiApiImpl] Wallet not initialized, creating mock DID")
                    let didId = "did-\(UUID().uuidString)"
                    let didString = generateDidString(method: method)
                    let isDefault = dids.isEmpty

                    let newDid = DidDto(
                        id: didId,
                        didString: didString,
                        method: method,
                        keyType: keyType,
                        createdAt: ISO8601DateFormatter().string(from: Date()),
                        isDefault: isDefault,
                        metadata: ["source": "manual", "sdk": false]
                    )

                    dids.append(newDid)
                    completion(.success(newDid))
                    return
                }

                // The EUDI SDK manages keys internally
                // We'll create a DID that represents usage of the SDK's internal key management
                let didId = "did-manual-\(UUID().uuidString)"
                let didString = generateDidString(method: method)
                let isDefault = dids.filter { $0.id != "did-wallet-holder" }.isEmpty

                // Update other manual DIDs to not be default
                if isDefault {
                    for i in 0..<dids.count {
                        if dids[i].id != "did-wallet-holder" {
                            dids[i].isDefault = false
                        }
                    }
                }

                let newDid = DidDto(
                    id: didId,
                    didString: didString,
                    method: method,
                    keyType: keyType,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    isDefault: isDefault,
                    metadata: [
                        "source": "manual", "sdk": true,
                        "walletKeys": wallet.storage.docModels.count,
                    ]
                )

                dids.append(newDid)
                print("[EudiSsiApiImpl] Created manual DID: \(didString)")
                completion(.success(newDid))
            } catch {
                print("[EudiSsiApiImpl] Error creating DID: \(error)")
                completion(.failure(error))
            }
        }
    }

    func getDids(completion: @escaping (Result<[DidDto], Error>) -> Void) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print("[EudiSsiApiImpl] getDids() called")

                guard isInitialized, let wallet = wallet as? EudiWallet else {
                    print("[EudiSsiApiImpl] Wallet not initialized, returning cached DIDs")
                    completion(.success(dids))
                    return
                }

                // Extract DIDs from credentials in the wallet
                var extractedDids: [DidDto] = []

                // Get all documents (count from different sources)
                let issuedDocs = wallet.storage.docModels
                let pendingCount = wallet.storage.pendingDocuments.count
                let deferredCount = wallet.storage.deferredDocuments.count
                let totalCredentials = issuedDocs.count + pendingCount + deferredCount

                print(
                    "[EudiSsiApiImpl] Found \(issuedDocs.count) issued, \(pendingCount) pending, \(deferredCount) deferred documents"
                )

                // Create a DID entry for the wallet's holder
                // The EUDI SDK manages keys internally, we'll create a representative DID
                if totalCredentials > 0 {
                    let walletDidId = "did-wallet-holder"

                    // Check if we already have this DID
                    if !dids.contains(where: { $0.id == walletDidId }) {
                        let walletDid = DidDto(
                            id: walletDidId,
                            didString:
                                "did:key:z6Mk\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(44))",
                            method: "did:key",
                            keyType: "Ed25519",
                            createdAt: ISO8601DateFormatter().string(from: Date()),
                            isDefault: true,
                            metadata: ["source": "EUDI Wallet", "credentials": totalCredentials]
                        )
                        extractedDids.append(walletDid)
                        print("[EudiSsiApiImpl] Created wallet holder DID: \(walletDid.didString)")
                    }
                }

                // Merge with any manually created DIDs
                let allDids = extractedDids + dids.filter { $0.id != "did-wallet-holder" }

                // Update internal storage
                dids = allDids

                print("[EudiSsiApiImpl] Returning \(allDids.count) DIDs")
                completion(.success(allDids))
            } catch {
                print("[EudiSsiApiImpl] Error getting DIDs: \(error)")
                completion(.success(dids))
            }
        }
    }

    func getDid(didId: String, completion: @escaping (Result<DidDto?, Error>) -> Void) {
        Task {
            let did = dids.first { $0.id == didId }
            completion(.success(did))
        }
    }

    func deleteDid(didId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            let initialCount = dids.count
            dids.removeAll { $0.id == didId }
            let removed = dids.count < initialCount
            completion(.success(removed))
        }
    }

    // MARK: - Credential Management

    func getCredentials(completion: @escaping (Result<[CredentialDto], Error>) -> Void) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print("[EudiSsiApiImpl] getCredentials() called")

                guard isInitialized else {
                    print("[EudiSsiApiImpl] Wallet not initialized, returning empty")
                    completion(.success([]))
                    return
                }

                guard let wallet = wallet as? EudiWallet else {
                    print("[EudiSsiApiImpl] Failed to cast wallet to EudiWallet, returning empty")
                    completion(.success([]))
                    return
                }

                print("[EudiSsiApiImpl] Fetching credentials from wallet storage...")

                // Get all documents (issued, pending, and deferred)
                let issuedDocs = wallet.storage.docModels
                let pendingDocs = wallet.storage.pendingDocuments
                let deferredDocs = wallet.storage.deferredDocuments

                print(
                    "[EudiSsiApiImpl] Found \(issuedDocs.count) issued, \(pendingDocs.count) pending, \(deferredDocs.count) deferred documents"
                )

                // Map issued documents
                var credentials = issuedDocs.map { documentToCredentialDto($0) }

                // Add pending documents
                for doc in pendingDocs {
                    let credential = CredentialDto(
                        id: doc.id,
                        name: doc.docType ?? "Credential",
                        type: doc.docType ?? "VerifiableCredential",
                        format: "mso_mdoc",
                        issuerName: "EUDI Issuer",
                        issuedDate: ISO8601DateFormatter().string(from: doc.createdAt),
                        claims: [:],
                        state: "pending"
                    )
                    credentials.append(credential)
                }

                // Add deferred documents
                for doc in deferredDocs {
                    let credential = CredentialDto(
                        id: doc.id,
                        name: doc.docType ?? "Credential",
                        type: doc.docType ?? "VerifiableCredential",
                        format: "mso_mdoc",
                        issuerName: "EUDI Issuer",
                        issuedDate: ISO8601DateFormatter().string(from: doc.createdAt),
                        claims: [:],
                        state: "deferred"
                    )
                    credentials.append(credential)
                }

                print("[EudiSsiApiImpl] Mapped to \(credentials.count) total credentials")
                completion(.success(credentials))
            } catch {
                print("[EudiSsiApiImpl] Failed to get credentials: \(error)")
                completion(.success([]))
            }
        }
    }

    func getCredential(
        credentialId: String, completion: @escaping (Result<CredentialDto?, Error>) -> Void
    ) {
        Task {
            guard let wallet = wallet as? EudiWallet else {
                completion(.success(nil))
                return
            }

            // Search in issued documents
            if let doc = wallet.storage.docModels.first(where: { $0.id == credentialId }) {
                completion(.success(documentToCredentialDto(doc)))
                return
            }

            // Search in pending documents
            if let doc = wallet.storage.pendingDocuments.first(where: { $0.id == credentialId }) {
                let credential = CredentialDto(
                    id: doc.id,
                    name: doc.displayName ?? doc.docType ?? "Credential",
                    type: doc.docType ?? "VerifiableCredential",
                    format: doc.docDataFormat == .cbor ? "mso_mdoc" : "vc+sd-jwt",
                    issuerName: "EUDI Issuer",
                    issuedDate: ISO8601DateFormatter().string(from: doc.createdAt),
                    claims: [:],
                    state: "pending"
                )
                completion(.success(credential))
                return
            }

            completion(.success(nil))
        }
    }

    func acceptCredentialOffer(
        offerId: String, holderDidId: String?,
        completion: @escaping (Result<CredentialDto?, Error>) -> Void
    ) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print("[EudiSsiApiImpl] Processing credential offer: \(offerId)")

                guard isInitialized else {
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Wallet not initialized"])
                }

                guard let wallet = wallet as? EudiWallet else {
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Wallet not available"])
                }

                print("[EudiSsiApiImpl] Resolving offer document types...")

                // Resolve offer to get available document types
                let offeredModel = try await wallet.resolveOfferUrlDocTypes(offerUri: offerId)

                // Get all offered documents
                let docTypes = offeredModel.docModels

                print("[EudiSsiApiImpl] Found \(docTypes.count) document types in offer")

                // Issue all documents from the offer
                // The SDK handles OAuth automatically via ASWebAuthenticationSession
                let issuedDocuments = try await wallet.issueDocumentsByOfferUrl(
                    offerUri: offerId,
                    docTypes: docTypes,
                    txCodeValue: nil
                )

                print("[EudiSsiApiImpl] Returned \(issuedDocuments.count) documents")
                for doc in issuedDocuments {
                    print(
                        "[EudiSsiApiImpl]   Doc id=\(doc.id), status=\(doc.status), docType=\(doc.docType ?? "nil"), authUrl=\(doc.authorizePresentationUrl ?? "nil")"
                    )
                }

                // Check wallet storage immediately after issuance
                let storedDocs = wallet.storage.docModels
                let pendingDocs = wallet.storage.pendingDocuments
                let deferredDocs = wallet.storage.deferredDocuments
                print(
                    "[EudiSsiApiImpl] Storage: issued=\(storedDocs.count), pending=\(pendingDocs.count), deferred=\(deferredDocs.count)"
                )

                // Convert first issued document to CredentialDto
                if let firstDoc = issuedDocuments.first {
                    let credential = CredentialDto(
                        id: firstDoc.id,
                        name: firstDoc.displayName ?? firstDoc.docType ?? "Credential",
                        type: firstDoc.docType ?? "VerifiableCredential",
                        format: firstDoc.docDataFormat == .cbor ? "mso_mdoc" : "vc+sd-jwt",
                        issuerName: "EUDI Issuer",
                        issuedDate: ISO8601DateFormatter().string(from: firstDoc.createdAt),
                        claims: [:],
                        state: firstDoc.status.rawValue
                    )
                    completion(.success(credential))
                } else {
                    completion(.success(nil))
                }
            } catch {
                print("[EudiSsiApiImpl] Failed to accept credential offer: \(error)")
                completion(.failure(error))
            }
        }
    }

    func deleteCredential(credentialId: String, completion: @escaping (Result<Bool, Error>) -> Void)
    {
        Task {
            // TODO: Implement with real SDK
            // try await wallet?.deleteDocument(id: credentialId, status: .issued)
            completion(.success(false))
        }
    }

    func checkCredentialStatus(
        credentialId: String, completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            completion(.success("unknown"))
        }
    }

    // MARK: - Presentation

    func processPresentationRequest(
        url: String, completion: @escaping (Result<PresentationRequestDto?, Error>) -> Void
    ) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print("[EudiSsiApiImpl] Processing OpenID4VP presentation request: \(url)")

                guard isInitialized, let wallet = wallet as? EudiWallet else {
                    print("[EudiSsiApiImpl] Wallet not initialized")
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Wallet not initialized"])
                }

                // Convert URL string to Data for FlowType
                guard let urlData = url.data(using: .utf8) else {
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL encoding"])
                }

                // Begin OpenID4VP presentation session
                // Log wallet documents before starting
                let docModels = wallet.storage.docModels
                print("[EudiSsiApiImpl] Wallet docModels count: \(docModels.count)")
                for doc in docModels {
                    print(
                        "[EudiSsiApiImpl]   Doc: id=\(doc.id), docType=\(doc.docType ?? "nil"), displayName=\(doc.displayName ?? "nil")"
                    )
                }
                print("[EudiSsiApiImpl] Pending docs: \(wallet.storage.pendingDocuments.count)")
                print("[EudiSsiApiImpl] Deferred docs: \(wallet.storage.deferredDocuments.count)")

                print("[EudiSsiApiImpl] Creating presentation session...")
                let session = await wallet.beginPresentation(
                    flow: .openid4vp(qrCode: urlData),
                    sessionTransactionLogger: nil
                )

                // Log session state after creation
                print("[EudiSsiApiImpl] Session created. Status: \(session.status)")
                print(
                    "[EudiSsiApiImpl] DocIdToPresentInfo keys: \(session.docIdToPresentInfo?.keys.sorted() ?? [])"
                )
                if let presentInfo = session.docIdToPresentInfo {
                    for (docId, info) in presentInfo {
                        print(
                            "[EudiSsiApiImpl]   PresentInfo: docId=\(docId), docType=\(info.docType), format=\(info.docDataFormat), displayName=\(info.displayName ?? "nil")"
                        )
                    }
                }

                // Receive the presentation request from verifier
                print("[EudiSsiApiImpl] Receiving presentation request...")
                guard let requestInfo = await session.receiveRequest() else {
                    let errorMsg =
                        session.uiError?.description ?? session.uiError?.errorDescription
                        ?? "Unknown error"
                    let docCount = wallet.storage.docModels.count
                    let pendingCount = wallet.storage.pendingDocuments.count
                    let deferredCount = wallet.storage.deferredDocuments.count
                    let presentInfoCount = session.docIdToPresentInfo?.count ?? 0
                    let detail =
                        "SDK error: \(errorMsg) | docModels=\(docCount), pending=\(pendingCount), deferred=\(deferredCount), presentInfo=\(presentInfoCount)"
                    print("[EudiSsiApiImpl] \(detail)")
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: detail])
                }

                print("[EudiSsiApiImpl] Request received successfully")
                print(
                    "[EudiSsiApiImpl] Verifier: \(requestInfo.readerLegalName ?? requestInfo.readerCertificateIssuer ?? "Unknown")"
                )
                print(
                    "[EudiSsiApiImpl] Disclosed documents count: \(session.disclosedDocuments.count)"
                )

                // Generate unique interaction ID
                let interactionId = "interaction-\(UUID().uuidString)"

                // Store session for later use in submission
                pendingSessions[interactionId] = session

                // Parse the request into our DTO format
                let presentationRequest = try parsePresentationRequest(
                    interactionId: interactionId,
                    requestInfo: requestInfo,
                    session: session
                )

                print("[EudiSsiApiImpl] Successfully parsed presentation request")
                print("[EudiSsiApiImpl] Verifier: \(presentationRequest.verifierName)")
                print(
                    "[EudiSsiApiImpl] Requested claims: \(presentationRequest.requestedClaims.count)"
                )
                print(
                    "[EudiSsiApiImpl] Matching credentials: \(presentationRequest.matchingCredentialIds.count)"
                )

                completion(.success(presentationRequest))
            } catch {
                print("[EudiSsiApiImpl] Failed to process presentation request: \(error)")
                completion(.failure(error))
            }
        }
    }

    func submitPresentationWithClaims(
        submission: PresentationSubmissionDto,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print(
                    "[EudiSsiApiImpl] Submitting presentation for interaction: \(submission.interactionId)"
                )
                print("[EudiSsiApiImpl] Credential ID: \(submission.credentialId)")
                print("[EudiSsiApiImpl] Selected claims: \(submission.selectedClaims)")

                // Retrieve the stored presentation session
                guard let session = pendingSessions[submission.interactionId] else {
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Presentation session not found"])
                }

                // Build RequestItems from user's selected claims
                let selectedClaimsNonNil = submission.selectedClaims.compactMap { $0 }
                let itemsToSend = try buildRequestItems(
                    from: session.disclosedDocuments,
                    credentialId: submission.credentialId,
                    selectedClaims: selectedClaimsNonNil
                )

                print("[EudiSsiApiImpl] Built request items for \(itemsToSend.count) documents")

                // Send response to verifier via EUDI SDK
                await session.sendResponse(
                    userAccepted: true,
                    itemsToSend: itemsToSend,
                    onSuccess: { @Sendable redirectUrl in
                        print("[EudiSsiApiImpl] Presentation response sent")
                        if let url = redirectUrl {
                            print("[EudiSsiApiImpl] Redirect URL: \(url)")
                        }
                    }
                )

                // Check if submission was successful
                guard session.status == .responseSent else {
                    throw NSError(
                        domain: "EudiSsiApiImpl", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: session.uiError?.description
                                ?? "Failed to send response"
                        ])
                }

                // Clean up
                pendingSessions.removeValue(forKey: submission.interactionId)

                print("[EudiSsiApiImpl] Presentation submitted successfully")
                completion(.success(true))
            } catch {
                print("[EudiSsiApiImpl] Failed to submit presentation: \(error)")
                completion(.failure(error))
            }
        }
    }

    func submitPresentation(
        interactionId: String, credentialIds: [String],
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            // Legacy method - just mark as accepted for backward compatibility
            if let index = interactions.firstIndex(where: { $0.id == interactionId }) {
                interactions[index].status = "accepted"
                interactions[index].completedAt = ISO8601DateFormatter().string(from: Date())
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }
    }

    func rejectPresentationRequest(
        interactionId: String, completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            // Clean up pending presentation session
            pendingSessions.removeValue(forKey: interactionId)

            if let index = interactions.firstIndex(where: { $0.id == interactionId }) {
                interactions[index].status = "rejected"
                interactions[index].completedAt = ISO8601DateFormatter().string(from: Date())
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }
    }

    // MARK: - Presentation Helper Methods

    /// Parse PresentationSession and UserRequestInfo into our PresentationRequestDto format
    private func parsePresentationRequest(
        interactionId: String,
        requestInfo: UserRequestInfo,
        session: PresentationSession
    ) throws -> PresentationRequestDto {
        // Extract verifier information
        let verifierName =
            requestInfo.readerLegalName ?? requestInfo.readerCertificateIssuer ?? "Unknown Verifier"
        let verifierUrl = "openid4vp://"  // TODO: Extract actual URL if available

        // Parse requested claims from all disclosed documents
        var requestedClaims: [RequestedClaimDto] = []
        var matchingCredentialIds: [String] = []
        var intentToRetain: [String: Bool] = [:]

        for docElement in session.disclosedDocuments {
            // Add document ID to matching list
            matchingCredentialIds.append(docElement.docId)

            // Extract claims based on document type
            switch docElement {
            case .msoMdoc(let mdocElements):
                // Parse mso_mdoc elements (ISO 18013-5 format)
                for namespace in mdocElements.nameSpacedElements {
                    for element in namespace.elements {
                        let claim = RequestedClaimDto(
                            claimName: element.elementIdentifier,
                            claimPath: "\(namespace.nameSpace).\(element.elementIdentifier)",
                            required: !element.isOptional,
                            purpose: nil
                        )
                        requestedClaims.append(claim)
                        intentToRetain[element.elementIdentifier] = element.intentToRetain
                    }
                }

            case .sdJwt(let sdJwtElements):
                // Parse SD-JWT elements (SD-JWT-VC format)
                for sdItem in sdJwtElements.sdJwtElements {
                    let claimName = sdItem.elementPath.joined(separator: ".")
                    let claim = RequestedClaimDto(
                        claimName: claimName,
                        claimPath: claimName,
                        required: !sdItem.isOptional,
                        purpose: nil
                    )
                    requestedClaims.append(claim)
                    intentToRetain[claimName] = sdItem.intentToRetain
                }
            }
        }

        // Intent-to-retain information extracted from SDK elements

        return PresentationRequestDto(
            interactionId: interactionId,
            verifierName: verifierName,
            verifierUrl: verifierUrl,
            verifierLogo: nil,
            requestedClaims: requestedClaims,
            matchingCredentialIds: matchingCredentialIds,
            intentToRetain: intentToRetain
        )
    }

    /// Build RequestItems from user's selected claims
    private func buildRequestItems(
        from disclosedDocuments: [DocElements],
        credentialId: String,
        selectedClaims: [String]
    ) throws -> RequestItems {
        var requestItems: RequestItems = [:]

        // Find the document that matches the credentialId
        guard let selectedDoc = disclosedDocuments.first(where: { $0.docId == credentialId }) else {
            throw NSError(
                domain: "EudiSsiApiImpl", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Document not found in session"])
        }

        // Use the SDK's built-in selection mechanism:
        // Set isSelected on each element based on user's selectedClaims,
        // then use selectedItemsDictionary to build properly formatted RequestItems
        switch selectedDoc {
        case .msoMdoc(let mdocElements):
            for namespace in mdocElements.nameSpacedElements {
                for element in namespace.elements {
                    // Select if user chose this claim OR if it's required
                    element.isSelected =
                        selectedClaims.contains(element.elementIdentifier) || !element.isOptional
                }
            }
            requestItems[credentialId] = mdocElements.selectedItemsDictionary

        case .sdJwt(let sdJwtElements):
            for sdItem in sdJwtElements.sdJwtElements {
                let claimName = sdItem.elementPath.joined(separator: ".")
                // Select if user chose this claim OR if it's required
                sdItem.isSelected = selectedClaims.contains(claimName) || !sdItem.isOptional
            }
            requestItems[credentialId] = sdJwtElements.selectedItemsDictionary
        }

        return requestItems
    }

    func getInteractionHistory(completion: @escaping (Result<[InteractionDto], Error>) -> Void) {
        Task {
            completion(.success(interactions))
        }
    }

    // MARK: - Backup

    func exportBackup(completion: @escaping (Result<[String?: Any?], Error>) -> Void) {
        Task {
            let backup: [String?: Any?] = [
                "version": "1.0",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "dids": dids.count,
                "credentials": 0,
                "walletType": "EUDI iOS",
            ]
            completion(.success(backup))
        }
    }

    func importBackup(backupData: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            completion(.success(true))
        }
    }

    // MARK: - Configuration

    func getSupportedDidMethods(completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            completion(.success(["did:key", "did:web", "did:jwk", "did:ebsi"]))
        }
    }

    func getSupportedCredentialFormats(completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            completion(.success(["mso_mdoc", "sd-jwt-vc", "JWT_VC", "JSON-LD"]))
        }
    }

    func uninitialize(completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            isInitialized = false
            wallet = nil
            dids.removeAll()
            interactions.removeAll()
            completion(.success(true))
        }
    }

    // MARK: - Authorization Callback Handling

    /// Handle authorization callback from Flutter/Pigeon
    ///
    /// NOTE: With the real EUDI iOS SDK, manual callback handling is NOT needed!
    ///
    /// The EUDI iOS SDK uses ASWebAuthenticationSession which handles OAuth automatically:
    /// 1. When issueDocumentsByOfferUrl() is called, the SDK internally opens the browser
    /// 2. ASWebAuthenticationSession captures the callback URL automatically
    /// 3. The SDK resumes credential issuance
    /// 4. The await completes with the issued credential
    ///
    /// This method exists only for API compatibility and will return false.
    func handleAuthorizationCallback(
        authorizationResponseUri: String, completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            print("[EudiSsiApiImpl] Authorization callback received: \(authorizationResponseUri)")
            print(
                "[EudiSsiApiImpl] INFO: Real EUDI iOS SDK handles OAuth automatically via ASWebAuthenticationSession"
            )
            print(
                "[EudiSsiApiImpl] INFO: No manual callback handling needed - OAuth is handled internally by SDK"
            )
            completion(.success(false))
        }
    }

    func getDebugLogs(completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            // TODO: Implement log retrieval from SDK
            let logs = """
                EUDI iOS SDK Integration Status:
                - SDK integrated: NO (pending)
                - OAuth support: NO (requires SDK)

                To enable:
                1. Add EudiWalletKit via SPM in Xcode
                2. Uncomment SDK imports and initialization code
                3. Rebuild the app

                See EudiSsiApiImpl.swift for detailed integration instructions.
                """
            completion(.success(logs))
        }
    }

    // MARK: - Helper Functions

    private func generateDidString(method: String) -> String {
        let randomId = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        switch method {
        case "did:key":
            return "did:key:z6Mk\(String(randomId.prefix(44)))"
        case "did:web":
            return "did:web:example.com:user:\(String(randomId.prefix(16)))"
        case "did:jwk":
            return "did:jwk:\(String(randomId.prefix(32)))"
        case "did:ebsi":
            return "did:ebsi:\(String(randomId.prefix(32)))"
        default:
            return "did:key:z6Mk\(String(randomId.prefix(44)))"
        }
    }

    private func documentToCredentialDto(_ document: DocClaimsDecodable) -> CredentialDto {
        let formatter = ISO8601DateFormatter()
        // Extract claims from document
        var claims: [String: String] = [:]
        for claim in document.docClaims {
            claims[claim.name] = claim.stringValue
        }
        return CredentialDto(
            id: document.id,
            name: document.displayName ?? document.docType ?? "Credential",
            type: document.docType ?? "VerifiableCredential",
            format: document.docDataFormat == .cbor ? "mso_mdoc" : "vc+sd-jwt",
            issuerName: document.issuerDisplay?.first?.name ?? "EUDI Issuer",
            issuedDate: formatter.string(from: document.createdAt),
            claims: claims,
            state: "valid"
        )
    }
}
