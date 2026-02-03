import Foundation
import Flutter

class SprucekitSsiApiImpl: NSObject, SsiApi {

    // Storage for DIDs and credentials (in-memory)
    private var dids: [DidDto] = []
    private var credentials: [CredentialDto] = []
    private var interactions: [InteractionDto] = []

    private var isInitialized = false

    func initialize(completion: @escaping (Result<OperationResult, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            // Initialize SpruceKit SDK here
            self.isInitialized = true

            let result = OperationResult(
                success: true,
                error: nil,
                data: ["initialized": true]
            )

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }

    func getVersion() throws -> String {
        return "SpruceKit Mobile v0.13.16 (iOS)"
    }

    func createDid(method: String, keyType: String, completion: @escaping (Result<DidDto?, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let didId = "did-\(UUID().uuidString)"
            let didString = self.generateDidString(method: method)
            let isDefault = self.dids.isEmpty

            // If this is default, unset other defaults
            if isDefault {
                for i in 0..<self.dids.count {
                    var did = self.dids[i]
                    did.isDefault = false
                    self.dids[i] = did
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

            self.dids.append(newDid)

            DispatchQueue.main.async {
                completion(.success(newDid))
            }
        }
    }

    func getDids(completion: @escaping (Result<[DidDto], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(self.dids))
            }
        }
    }

    func getDid(didId: String, completion: @escaping (Result<DidDto?, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let did = self.dids.first { $0.id == didId }
            DispatchQueue.main.async {
                completion(.success(did))
            }
        }
    }

    func deleteDid(didId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let initialCount = self.dids.count
            self.dids.removeAll { $0.id == didId }
            let removed = self.dids.count < initialCount

            DispatchQueue.main.async {
                completion(.success(removed))
            }
        }
    }

    func getCredentials(completion: @escaping (Result<[CredentialDto], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(self.credentials))
            }
        }
    }

    func getCredential(credentialId: String, completion: @escaping (Result<CredentialDto?, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let credential = self.credentials.first { $0.id == credentialId }
            DispatchQueue.main.async {
                completion(.success(credential))
            }
        }
    }

    func acceptCredentialOffer(offerId: String, holderDidId: String?, completion: @escaping (Result<CredentialDto?, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let holderDid = holderDidId.flatMap { id in
                self.dids.first { $0.id == id }?.didString
            } ?? self.dids.first?.didString ?? "did:key:no-did-created"

            let credentialId = "cred-\(UUID().uuidString)"

            let newCredential = CredentialDto(
                id: credentialId,
                name: "New Credential",
                type: "VerifiableCredential",
                format: "JWT_VC",
                issuerName: "Example Issuer",
                issuerDid: "did:web:example.issuer.com",
                holderDid: holderDid,
                issuedDate: ISO8601DateFormatter().string(from: Date()),
                expiryDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(365 * 24 * 60 * 60)),
                claims: ["credentialSubject": "Sample Data"],
                proofType: "JwtProof2020",
                state: "valid",
                backgroundColor: "#6366F1",
                textColor: "#FFFFFF"
            )

            self.credentials.append(newCredential)

            DispatchQueue.main.async {
                completion(.success(newCredential))
            }
        }
    }

    func deleteCredential(credentialId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let initialCount = self.credentials.count
            self.credentials.removeAll { $0.id == credentialId }
            let removed = self.credentials.count < initialCount

            DispatchQueue.main.async {
                completion(.success(removed))
            }
        }
    }

    func checkCredentialStatus(credentialId: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success("valid"))
            }
        }
    }

    func processPresentationRequest(url: String, completion: @escaping (Result<InteractionDto?, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let interactionId = "interaction-\(UUID().uuidString)"

            let interaction = InteractionDto(
                id: interactionId,
                type: "presentation_request",
                verifierName: "Example Verifier",
                requestedCredentials: ["VerifiableCredential"],
                timestamp: ISO8601DateFormatter().string(from: Date()),
                status: "pending",
                completedAt: nil
            )

            self.interactions.append(interaction)

            DispatchQueue.main.async {
                completion(.success(interaction))
            }
        }
    }

    func submitPresentation(interactionId: String, credentialIds: [String], completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            if let index = self.interactions.firstIndex(where: { $0.id == interactionId }) {
                var interaction = self.interactions[index]
                interaction.status = "accepted"
                interaction.completedAt = ISO8601DateFormatter().string(from: Date())
                self.interactions[index] = interaction

                DispatchQueue.main.async {
                    completion(.success(true))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.success(false))
                }
            }
        }
    }

    func rejectPresentationRequest(interactionId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            if let index = self.interactions.firstIndex(where: { $0.id == interactionId }) {
                var interaction = self.interactions[index]
                interaction.status = "rejected"
                interaction.completedAt = ISO8601DateFormatter().string(from: Date())
                self.interactions[index] = interaction

                DispatchQueue.main.async {
                    completion(.success(true))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.success(false))
                }
            }
        }
    }

    func getInteractionHistory(completion: @escaping (Result<[InteractionDto], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(self.interactions))
            }
        }
    }

    func exportBackup(completion: @escaping (Result<[String? : Any?], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let backup: [String?: Any?] = [
                "version": "1.0",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "dids": self.dids.count,
                "credentials": self.credentials.count
            ]

            DispatchQueue.main.async {
                completion(.success(backup))
            }
        }
    }

    func importBackup(backupData: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(true))
            }
        }
    }

    func getSupportedDidMethods(completion: @escaping (Result<[String], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(["did:key", "did:web", "did:jwk"]))
            }
        }
    }

    func getSupportedCredentialFormats(completion: @escaping (Result<[String], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                completion(.success(["JWT_VC", "SD-JWT", "ISO_MDL", "JSON-LD"]))
            }
        }
    }

    func uninitialize(completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            self.isInitialized = false
            self.dids.removeAll()
            self.credentials.removeAll()
            self.interactions.removeAll()

            DispatchQueue.main.async {
                completion(.success(true))
            }
        }
    }

    // Helper functions
    private func generateDidString(method: String) -> String {
        let randomId = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        switch method {
        case "did:key":
            return "did:key:z6Mk\(String(randomId.prefix(44)))"
        case "did:web":
            return "did:web:example.com:user:\(String(randomId.prefix(16)))"
        case "did:jwk":
            return "did:jwk:\(String(randomId.prefix(32)))"
        default:
            return "did:key:z6Mk\(String(randomId.prefix(44)))"
        }
    }
}
