import Foundation
import Flutter
import Security
// IMPORTANT: After adding EudiWalletKit via SPM in Xcode, uncomment the line below:
// import EudiWalletKit

/// Production EUDI Wallet implementation for iOS
/// Uses the official EudiWalletKit SDK with OpenID4VCI/VP support
class EudiSsiApiImpl: NSObject, SsiApi {

    // Storage for DIDs and interactions (credentials managed by SDK)
    private var dids: [DidDto] = []
    private var interactions: [InteractionDto] = []

    // EUDI Wallet instance (will be initialized with real SDK)
    private var wallet: Any? // Type will be: EudiWallet once SDK is imported
    private var isInitialized = false

    // MARK: - Initialization

    func initialize(completion: @escaping (Result<OperationResult, Error>) -> Void) {
        Task {
            do {
                print("[EudiSsiApiImpl] Initializing EUDI Wallet SDK...")

                // TODO: After adding EudiWalletKit via SPM, replace this with real initialization:
                //
                // let config = OpenId4VciConfiguration(
                //     credentialIssuerURL: "https://issuer.eudiw.dev",
                //     clientId: "wallet-dev",
                //     authFlowRedirectionURI: URL(string: "eudi-openid4ci://authorize")!,
                //     usePAR: true,
                //     useDpopIfSupported: true
                // )
                //
                // let wallet = try EudiWallet(
                //     serviceName: "com.example.ssi.eudi.wallet",
                //     trustedReaderCertificates: [],
                //     userAuthenticationRequired: false,
                //     openID4VciConfigurations: ["issuer.eudiw.dev": config]
                // )
                //
                // self.wallet = wallet
                // self.isInitialized = true

                // Temporary mock initialization until SDK is added
                print("[EudiSsiApiImpl] WARNING: Using mock initialization")
                print("[EudiSsiApiImpl] To enable real SDK:")
                print("[EudiSsiApiImpl] 1. Add EudiWalletKit via SPM in Xcode")
                print("[EudiSsiApiImpl] 2. Uncomment 'import EudiWalletKit' at top of file")
                print("[EudiSsiApiImpl] 3. Uncomment real initialization code above")

                self.isInitialized = true

                let result = OperationResult(
                    success: true,
                    error: nil,
                    data: [
                        "initialized": true,
                        "version": "EUDI iOS SDK (pending integration)",
                        "storage": "iOS Secure Storage"
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

    func createDid(method: String, keyType: String, completion: @escaping (Result<DidDto?, Error>) -> Void) {
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
                guard isInitialized else {
                    completion(.success([]))
                    return
                }

                // TODO: After SDK integration, use real credential fetching:
                //
                // guard let wallet = wallet as? EudiWallet else {
                //     completion(.success([]))
                //     return
                // }
                //
                // let documents = try await wallet.storage.docModels
                // let credentials = documents.map { documentToCredentialDto($0) }
                // completion(.success(credentials))

                // Temporary: return empty for now
                completion(.success([]))
            } catch {
                print("[EudiSsiApiImpl] Failed to get credentials: \(error)")
                completion(.success([]))
            }
        }
    }

    func getCredential(credentialId: String, completion: @escaping (Result<CredentialDto?, Error>) -> Void) {
        Task {
            // TODO: Implement with real SDK
            completion(.success(nil))
        }
    }

    func acceptCredentialOffer(offerId: String, holderDidId: String?, completion: @escaping (Result<CredentialDto?, Error>) -> Void) {
        Task {
            do {
                print("[EudiSsiApiImpl] ========================================")
                print("[EudiSsiApiImpl] Processing credential offer: \(offerId)")

                guard isInitialized else {
                    throw NSError(domain: "EudiSsiApiImpl", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Wallet not initialized"])
                }

                // TODO: After SDK integration, implement real credential issuance:
                //
                // guard let wallet = wallet as? EudiWallet else {
                //     throw NSError(domain: "EudiSsiApiImpl", code: -1,
                //                 userInfo: [NSLocalizedDescriptionKey: "Wallet not available"])
                // }
                //
                // // Parse offer URL
                // guard let offerURL = URL(string: offerId) else {
                //     throw NSError(domain: "EudiSsiApiImpl", code: -2,
                //                 userInfo: [NSLocalizedDescriptionKey: "Invalid offer URL"])
                // }
                //
                // print("[EudiSsiApiImpl] Resolving offer document types...")
                //
                // // Resolve offer to get available document types
                // let offeredModel = try await wallet.resolveOfferUrlDocTypes(offerUri: offerId)
                //
                // // Get all offered documents
                // let docTypes = offeredModel.offeredDocuments
                //
                // print("[EudiSsiApiImpl] Found \(docTypes.count) document types in offer")
                //
                // // Issue all documents from the offer
                // // The SDK handles OAuth automatically via ASWebAuthenticationSession
                // // This call will suspend until OAuth is complete (if needed)
                // let issuedDocuments = try await wallet.issueDocumentsByOfferUrl(
                //     offerUri: offerId,
                //     docTypes: docTypes,
                //     txCodeValue: nil
                // )
                //
                // print("[EudiSsiApiImpl] Successfully issued \(issuedDocuments.count) documents")
                //
                // // Convert first issued document to CredentialDto
                // if let firstDoc = issuedDocuments.first {
                //     let credential = documentToCredentialDto(firstDoc)
                //     completion(.success(credential))
                // } else {
                //     completion(.success(nil))
                // }

                // Temporary mock response
                print("[EudiSsiApiImpl] WARNING: Mock implementation - real SDK integration required")
                print("[EudiSsiApiImpl] OAuth flow not available until EudiWalletKit is added")

                throw NSError(domain: "EudiSsiApiImpl", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "SDK integration required. See comments in EudiSsiApiImpl.swift"])
            } catch {
                print("[EudiSsiApiImpl] Failed to accept credential offer: \(error)")
                completion(.failure(error))
            }
        }
    }

    func deleteCredential(credentialId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            // TODO: Implement with real SDK
            // try await wallet?.deleteDocument(id: credentialId, status: .issued)
            completion(.success(false))
        }
    }

    func checkCredentialStatus(credentialId: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            completion(.success("unknown"))
        }
    }

    // MARK: - Presentation

    func processPresentationRequest(url: String, completion: @escaping (Result<InteractionDto?, Error>) -> Void) {
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

    func submitPresentation(interactionId: String, credentialIds: [String], completion: @escaping (Result<Bool, Error>) -> Void) {
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

    func rejectPresentationRequest(interactionId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
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

    func exportBackup(completion: @escaping (Result<[String? : Any?], Error>) -> Void) {
        Task {
            let backup: [String?: Any?] = [
                "version": "1.0",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "dids": dids.count,
                "credentials": 0,
                "walletType": "EUDI iOS"
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
    func handleAuthorizationCallback(authorizationResponseUri: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            print("[EudiSsiApiImpl] Authorization callback received: \(authorizationResponseUri)")
            print("[EudiSsiApiImpl] INFO: Real EUDI iOS SDK handles OAuth automatically via ASWebAuthenticationSession")
            print("[EudiSsiApiImpl] INFO: No manual callback handling needed - OAuth is handled internally by SDK")
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

    // TODO: Implement after SDK integration
    // private func documentToCredentialDto(_ document: WalletStorage.Document) -> CredentialDto {
    //     let formatter = ISO8601DateFormatter()
    //     return CredentialDto(
    //         id: document.id,
    //         name: document.name,
    //         type: "VerifiableCredential",
    //         format: "mso_mdoc",
    //         issuerName: "EU Issuer",
    //         issuerDid: "did:web:issuer.europa.eu",
    //         holderDid: dids.first?.didString ?? "did:key:holder",
    //         issuedDate: formatter.string(from: document.createdAt),
    //         expiryDate: formatter.string(from: Date().addingTimeInterval(365*24*60*60)),
    //         claims: ["documentType": document.name],
    //         proofType: "ECDSA",
    //         state: "valid",
    //         backgroundColor: "#003399",
    //         textColor: "#FFCC00"
    //     )
    // }
}
