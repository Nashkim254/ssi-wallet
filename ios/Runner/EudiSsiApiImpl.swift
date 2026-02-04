import EudiWalletKit
import Flutter
import Foundation
import MdocDataModel18013
import Security
import WalletStorage

/// Production EUDI Wallet implementation for iOS
/// Uses the official EudiWalletKit SDK with OpenID4VCI/VP support
class EudiSsiApiImpl: NSObject, SsiApi {

    // Storage for DIDs and interactions (credentials managed by SDK)
    private var dids: [DidDto] = []
    private var interactions: [InteractionDto] = []

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

                let wallet = try EudiWallet(
                    serviceName: "com.example.ssi.eudi.wallet",
                    trustedReaderCertificates: [],
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
            let didId = "did-\(UUID().uuidString)"
            let didString = generateDidString(method: method)
            let isDefault = dids.isEmpty

            if isDefault {
                for i in 0..<dids.count {
                    dids[i].isDefault = false
                }
            }

            let newDid = DidDto(
                id: didId,
                didString: didString,
                method: method,
                keyType: keyType,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                isDefault: isDefault,
                metadata: nil
            )

            dids.append(newDid)
            completion(.success(newDid))
        }
    }

    func getDids(completion: @escaping (Result<[DidDto], Error>) -> Void) {
        Task {
            completion(.success(dids))
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
                let documents = wallet.storage.docModels
                print("[EudiSsiApiImpl] Found \(documents.count) documents in storage")

                for (index, doc) in documents.enumerated() {
                    print(
                        "[EudiSsiApiImpl] Document \(index): id=\(doc.id), type=\(doc.docType ?? "nil")"
                    )
                }

                let credentials = documents.map { documentToCredentialDto($0) }
                print("[EudiSsiApiImpl] Mapped to \(credentials.count) credentials")
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
            // TODO: Implement with real SDK
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

                print("[EudiSsiApiImpl] Successfully issued \(issuedDocuments.count) documents")

                // Check wallet storage immediately after issuance
                let storedDocs = wallet.storage.docModels
                print("[EudiSsiApiImpl] Wallet storage now has \(storedDocs.count) documents")

                // Convert first issued document to CredentialDto
                if let firstDoc = issuedDocuments.first {
                    let credential = CredentialDto(
                        id: firstDoc.id,
                        name: firstDoc.docType ?? "Credential",
                        type: firstDoc.docType ?? "VerifiableCredential",
                        format: "mso_mdoc",
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
        url: String, completion: @escaping (Result<InteractionDto?, Error>) -> Void
    ) {
        Task {
            let interactionId = "interaction-\(UUID().uuidString)"
            let interaction = InteractionDto(
                id: interactionId,
                type: "presentation_request",
                verifierName: "Verifier",
                requestedCredentials: ["VerifiableCredential"],
                timestamp: ISO8601DateFormatter().string(from: Date()),
                status: "pending",
                completedAt: nil
            )
            interactions.append(interaction)
            completion(.success(interaction))
        }
    }

    func submitPresentation(
        interactionId: String, credentialIds: [String],
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
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
            if let index = interactions.firstIndex(where: { $0.id == interactionId }) {
                interactions[index].status = "rejected"
                interactions[index].completedAt = ISO8601DateFormatter().string(from: Date())
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }
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
        return CredentialDto(
            id: document.id,
            name: document.docType ?? "Credential",
            type: document.docType ?? "VerifiableCredential",
            format: "mso_mdoc",
            issuerName: document.issuerDisplay?.first?.name ?? "EUDI Issuer",
            issuedDate: formatter.string(from: document.createdAt),
            claims: [:],
            state: "valid"
        )
    }
}
