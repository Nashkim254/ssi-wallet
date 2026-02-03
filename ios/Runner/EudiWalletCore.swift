import Foundation
import Security
import CryptoKit

/// Core EUDI Wallet implementation for iOS
/// Implements OpenID4VCI and OpenID4VP protocols
class EudiWalletCore {

    // MARK: - Properties

    private let keychainService = "com.example.ssi.eudi.wallet"
    private let documentsDirectory: URL
    private var configuration: WalletConfiguration

    // MARK: - Initialization

    init(configuration: WalletConfiguration) throws {
        self.configuration = configuration

        // Set up secure storage directory
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw WalletError.storageInitializationFailed
        }

        self.documentsDirectory = dir.appendingPathComponent("eudi_wallet", isDirectory: true)

        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: documentsDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }

    // MARK: - Key Management

    /// Generate a new key pair in Secure Enclave
    func generateKeyPair(tag: String, algorithm: KeyAlgorithm) throws -> SecKey {
        let tag = "\(keychainService).\(tag)".data(using: .utf8)!

        var attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag,
                kSecAttrAccessControl: try createAccessControl()
            ] as [CFString: Any]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw WalletError.keyGenerationFailed(error as Error)
            }
            throw WalletError.keyGenerationFailed(nil)
        }

        return privateKey
    }

    /// Retrieve existing key from Secure Enclave
    func getKey(tag: String) throws -> SecKey? {
        let tag = "\(keychainService).\(tag)".data(using: .utf8)!

        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw WalletError.keyRetrievalFailed(status)
        }

        return (item as! SecKey)
    }

    /// Delete key from Secure Enclave
    func deleteKey(tag: String) throws {
        let tag = "\(keychainService).\(tag)".data(using: .utf8)!

        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keyDeletionFailed(status)
        }
    }

    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                throw WalletError.accessControlCreationFailed(error as Error)
            }
            throw WalletError.accessControlCreationFailed(nil)
        }
        return accessControl
    }

    // MARK: - DID Operations

    /// Create a new DID
    func createDID(method: String, keyType: String) throws -> DIDDocument {
        let keyTag = "did-\(UUID().uuidString)"
        let algorithm = KeyAlgorithm.from(keyType: keyType)

        let privateKey = try generateKeyPair(tag: keyTag, algorithm: algorithm)
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw WalletError.publicKeyExtractionFailed
        }

        let publicKeyData = try exportPublicKey(publicKey)
        let didString = try generateDIDString(method: method, publicKey: publicKeyData)

        let didDoc = DIDDocument(
            id: UUID().uuidString,
            didString: didString,
            method: method,
            keyType: keyType,
            keyTag: keyTag,
            publicKey: publicKeyData,
            createdAt: Date()
        )

        try saveDIDDocument(didDoc)
        return didDoc
    }

    private func generateDIDString(method: String, publicKey: Data) throws -> String {
        switch method.lowercased() {
        case "did:key":
            // Multibase encoding for did:key
            let multicodecPrefix = Data([0xed, 0x01]) // ed25519-pub multicodec
            let combined = multicodecPrefix + publicKey
            let base58 = combined.base58EncodedString()
            return "did:key:z\(base58)"

        case "did:jwk":
            // JWK thumbprint for did:jwk
            let jwk: [String: Any] = [
                "kty": "EC",
                "crv": "P-256",
                "x": publicKey.base64URLEncodedString()
            ]
            let jwkData = try JSONSerialization.data(withJSONObject: jwk)
            let hash = SHA256.hash(data: jwkData)
            let thumbprint = Data(hash).base64URLEncodedString()
            return "did:jwk:\(thumbprint)"

        default:
            return "did:\(method):\(UUID().uuidString)"
        }
    }

    // MARK: - OpenID4VCI Implementation

    /// Accept a credential offer from an issuer
    func acceptCredentialOffer(offerURL: String, holderDID: String) async throws -> CredentialDocument {
        // Parse credential offer
        let offer = try parseCredentialOffer(offerURL)

        // Get access token
        let accessToken = try await requestAccessToken(
            tokenEndpoint: offer.tokenEndpoint,
            preAuthorizedCode: offer.preAuthorizedCode
        )

        // Request credential
        let credentialResponse = try await requestCredential(
            credentialEndpoint: offer.credentialEndpoint,
            accessToken: accessToken,
            format: offer.format,
            holderDID: holderDID
        )

        // Store credential
        let credential = CredentialDocument(
            id: UUID().uuidString,
            format: offer.format,
            credentialData: credentialResponse.credential,
            issuer: offer.issuerURL,
            subject: holderDID,
            issuedAt: Date(),
            expiresAt: credentialResponse.expiresAt,
            metadata: credentialResponse.metadata
        )

        try saveCredential(credential)
        return credential
    }

    private func parseCredentialOffer(_ url: String) throws -> CredentialOffer {
        // Parse OpenID4VCI credential offer URL
        guard let components = URLComponents(string: url) else {
            throw WalletError.invalidCredentialOffer
        }

        // Extract credential_offer or credential_offer_uri parameter
        if let offerParam = components.queryItems?.first(where: { $0.name == "credential_offer" })?.value,
           let offerData = offerParam.data(using: .utf8),
           let offerJSON = try? JSONSerialization.jsonObject(with: offerData) as? [String: Any] {
            return try CredentialOffer(json: offerJSON)
        }

        throw WalletError.invalidCredentialOffer
    }

    private func requestAccessToken(tokenEndpoint: String, preAuthorizedCode: String?) async throws -> String {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:pre-authorized_code"),
            URLQueryItem(name: "pre-authorized_code", value: preAuthorizedCode ?? "")
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WalletError.tokenRequestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw WalletError.invalidTokenResponse
        }

        return accessToken
    }

    private func requestCredential(
        credentialEndpoint: String,
        accessToken: String,
        format: String,
        holderDID: String
    ) async throws -> CredentialResponse {
        var request = URLRequest(url: URL(string: credentialEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "format": format,
            "proof": [
                "proof_type": "jwt",
                "jwt": try await generateProofJWT(holderDID: holderDID, audience: credentialEndpoint)
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WalletError.credentialRequestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let credential = json["credential"] as? String else {
            throw WalletError.invalidCredentialResponse
        }

        return CredentialResponse(
            credential: credential,
            expiresAt: nil,
            metadata: json
        )
    }

    // MARK: - OpenID4VP Implementation

    /// Process a presentation request from a verifier
    func processPresentationRequest(_ requestURL: String) async throws -> PresentationRequest {
        // Parse presentation request
        guard let components = URLComponents(string: requestURL) else {
            throw WalletError.invalidPresentationRequest
        }

        // Fetch request object if using request_uri
        var requestJSON: [String: Any]

        if let requestURI = components.queryItems?.first(where: { $0.name == "request_uri" })?.value {
            let (data, _) = try await URLSession.shared.data(from: URL(string: requestURI)!)
            requestJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        } else if let requestParam = components.queryItems?.first(where: { $0.name == "request" })?.value {
            // Decode JWT request
            requestJSON = try decodeJWT(requestParam)
        } else {
            throw WalletError.invalidPresentationRequest
        }

        return try PresentationRequest(json: requestJSON)
    }

    /// Submit a presentation to the verifier
    func submitPresentation(
        request: PresentationRequest,
        credentials: [String],
        holderDID: String
    ) async throws {
        // Create VP token
        let vpToken = try await createVPToken(
            credentials: credentials,
            holderDID: holderDID,
            nonce: request.nonce,
            audience: request.clientId
        )

        // Submit to response_uri
        var urlRequest = URLRequest(url: URL(string: request.responseURI)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "vp_token", value: vpToken),
            URLQueryItem(name: "presentation_submission", value: try createPresentationSubmission(credentials))
        ]
        urlRequest.httpBody = bodyComponents.query?.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WalletError.presentationSubmissionFailed
        }
    }

    // MARK: - JWT Operations

    private func generateProofJWT(holderDID: String, audience: String) async throws -> String {
        guard let didDoc = try loadDIDDocument(byDIDString: holderDID) else {
            throw WalletError.didNotFound
        }

        guard let privateKey = try getKey(tag: didDoc.keyTag) else {
            throw WalletError.keyNotFound
        }

        let header: [String: Any] = [
            "alg": "ES256",
            "typ": "openid4vci-proof+jwt",
            "kid": "\(holderDID)#key-1"
        ]

        let payload: [String: Any] = [
            "iss": holderDID,
            "aud": audience,
            "iat": Int(Date().timeIntervalSince1970),
            "nonce": UUID().uuidString
        ]

        return try signJWT(header: header, payload: payload, privateKey: privateKey)
    }

    private func createVPToken(
        credentials: [String],
        holderDID: String,
        nonce: String,
        audience: String
    ) async throws -> String {
        guard let didDoc = try loadDIDDocument(byDIDString: holderDID) else {
            throw WalletError.didNotFound
        }

        guard let privateKey = try getKey(tag: didDoc.keyTag) else {
            throw WalletError.keyNotFound
        }

        let header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "kid": "\(holderDID)#key-1"
        ]

        let payload: [String: Any] = [
            "iss": holderDID,
            "aud": audience,
            "iat": Int(Date().timeIntervalSince1970),
            "nonce": nonce,
            "vp": [
                "@context": ["https://www.w3.org/2018/credentials/v1"],
                "type": ["VerifiablePresentation"],
                "verifiableCredential": credentials
            ]
        ]

        return try signJWT(header: header, payload: payload, privateKey: privateKey)
    }

    private func signJWT(header: [String: Any], payload: [String: Any], privateKey: SecKey) throws -> String {
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerB64 = headerData.base64URLEncodedString()
        let payloadB64 = payloadData.base64URLEncodedString()
        let signingInput = "\(headerB64).\(payloadB64)"

        guard let signingData = signingInput.data(using: .utf8) else {
            throw WalletError.jwtSigningFailed
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            signingData as CFData,
            &error
        ) as Data? else {
            throw WalletError.jwtSigningFailed
        }

        let signatureB64 = signature.base64URLEncodedString()
        return "\(signingInput).\(signatureB64)"
    }

    private func decodeJWT(_ jwt: String) throws -> [String: Any] {
        let segments = jwt.split(separator: ".")
        guard segments.count == 3 else {
            throw WalletError.invalidJWT
        }

        guard let payloadData = Data(base64URLEncoded: String(segments[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw WalletError.invalidJWT
        }

        return payload
    }

    private func createPresentationSubmission(_ credentials: [String]) throws -> String {
        let submission: [String: Any] = [
            "id": UUID().uuidString,
            "definition_id": "presentation-definition",
            "descriptor_map": credentials.enumerated().map { index, _ in
                [
                    "id": "credential-\(index)",
                    "format": "jwt_vc",
                    "path": "$.verifiableCredential[\(index)]"
                ]
            }
        ]

        let data = try JSONSerialization.data(withJSONObject: submission)
        return String(data: data, encoding: .utf8)!
    }

    private func exportPublicKey(_ publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw WalletError.publicKeyExportFailed(error as Error)
            }
            throw WalletError.publicKeyExportFailed(nil)
        }
        return data
    }

    // MARK: - Storage

    private func saveDIDDocument(_ didDoc: DIDDocument) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(didDoc)
        let fileURL = documentsDirectory.appendingPathComponent("did-\(didDoc.id).json")
        try data.write(to: fileURL, options: [.completeFileProtection])
    }

    private func loadDIDDocument(byDIDString didString: String) throws -> DIDDocument? {
        let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        let didFiles = files.filter { $0.lastPathComponent.hasPrefix("did-") }

        for fileURL in didFiles {
            let data = try Data(contentsOf: fileURL)
            let didDoc = try JSONDecoder().decode(DIDDocument.self, from: data)
            if didDoc.didString == didString {
                return didDoc
            }
        }

        return nil
    }

    private func saveCredential(_ credential: CredentialDocument) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(credential)
        let fileURL = documentsDirectory.appendingPathComponent("cred-\(credential.id).json")
        try data.write(to: fileURL, options: [.completeFileProtection])
    }

    // MARK: - Public API Methods for EudiSsiApiImpl

    /// Issue a credential from an offer URL
    func issueCredentialFromOffer(offerURL: URL, holderDidId: String?) throws -> CredentialDto {
        // For now, create a mock credential based on the offer URL
        // In production, this would call the actual OpenID4VCI flow
        let credentialId = "eudi-ios-\(UUID().uuidString)"

        // Parse offer parameters
        var issuerUrl = "https://issuer.eudiw.dev"
        var docType = "eu.europa.ec.eudi.pid"

        if let components = URLComponents(url: offerURL, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            if let offerParam = queryItems.first(where: { $0.name == "credential_offer" })?.value,
               let decodedOffer = offerParam.removingPercentEncoding,
               let offerData = decodedOffer.data(using: .utf8),
               let offerJson = try? JSONSerialization.jsonObject(with: offerData) as? [String: Any],
               let credIssuer = offerJson["credential_issuer"] as? String {
                issuerUrl = credIssuer
            }
        }

        let holderDid = holderDidId ?? "did:key:holder"
        let now = Date()
        let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

        // Create credential document
        let credential = CredentialDocument(
            id: credentialId,
            format: "mso_mdoc",
            credentialData: "{\"docType\":\"\(docType)\"}",
            issuer: issuerUrl,
            subject: holderDid,
            issuedAt: now,
            expiresAt: expiryDate,
            metadata: ["offerUrl": offerURL.absoluteString]
        )

        // Save the credential
        try saveCredential(credential)

        // Convert to DTO
        return convertToCredentialDto(credential)
    }

    /// Get all stored credentials
    func getAllDocuments() throws -> [CredentialDto] {
        let files = try FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        )
        let credFiles = files.filter { $0.lastPathComponent.hasPrefix("cred-") }

        var credentials: [CredentialDto] = []
        for fileURL in credFiles {
            let data = try Data(contentsOf: fileURL)
            let credential = try JSONDecoder().decode(CredentialDocument.self, from: data)
            credentials.append(convertToCredentialDto(credential))
        }

        return credentials
    }

    /// Delete a credential by ID
    func deleteDocument(id: String) throws {
        let fileURL = documentsDirectory.appendingPathComponent("cred-\(id).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Convert CredentialDocument to CredentialDto
    private func convertToCredentialDto(_ credential: CredentialDocument) -> CredentialDto {
        let formatter = ISO8601DateFormatter()

        return CredentialDto(
            id: credential.id,
            name: extractCredentialName(from: credential),
            type: "VerifiableCredential",
            format: credential.format,
            issuerName: extractIssuerName(from: credential.issuer),
            issuerDid: credential.issuer,
            holderDid: credential.subject,
            issuedDate: formatter.string(from: credential.issuedAt),
            expiryDate: credential.expiresAt.map { formatter.string(from: $0) } ?? formatter.string(from: Date().addingTimeInterval(365 * 24 * 60 * 60)),
            claims: ["credentialData": credential.credentialData],
            proofType: "ECDSA",
            state: "valid",
            backgroundColor: "#003399",
            textColor: "#FFCC00"
        )
    }

    private func extractCredentialName(from credential: CredentialDocument) -> String {
        if let data = credential.credentialData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docType = json["docType"] as? String {
            if docType.contains("pid") {
                return "EU PID"
            }
            return docType
        }
        return "EUDI Credential"
    }

    private func extractIssuerName(from issuerUrl: String) -> String {
        if let url = URL(string: issuerUrl), let host = url.host {
            return host
        }
        return "EUDI Issuer"
    }
}

// MARK: - Supporting Types

struct WalletConfiguration {
    let issuerURL: String
    let clientId: String
    let redirectURI: String
}

enum KeyAlgorithm {
    case es256
    case es384
    case es512

    static func from(keyType: String) -> KeyAlgorithm {
        switch keyType.uppercased() {
        case "ES384": return .es384
        case "ES512": return .es512
        default: return .es256
        }
    }
}

struct DIDDocument: Codable {
    let id: String
    let didString: String
    let method: String
    let keyType: String
    let keyTag: String
    let publicKey: Data
    let createdAt: Date
}

struct CredentialDocument: Codable {
    let id: String
    let format: String
    let credentialData: String
    let issuer: String
    let subject: String
    let issuedAt: Date
    let expiresAt: Date?
    let metadata: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, format, credentialData, issuer, subject, issuedAt, expiresAt
    }

    init(id: String, format: String, credentialData: String, issuer: String, subject: String, issuedAt: Date, expiresAt: Date?, metadata: [String: Any]) {
        self.id = id
        self.format = format
        self.credentialData = credentialData
        self.issuer = issuer
        self.subject = subject
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        format = try container.decode(String.self, forKey: .format)
        credentialData = try container.decode(String.self, forKey: .credentialData)
        issuer = try container.decode(String.self, forKey: .issuer)
        subject = try container.decode(String.self, forKey: .subject)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        metadata = [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(format, forKey: .format)
        try container.encode(credentialData, forKey: .credentialData)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(subject, forKey: .subject)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}

struct CredentialOffer {
    let issuerURL: String
    let tokenEndpoint: String
    let credentialEndpoint: String
    let preAuthorizedCode: String?
    let format: String

    init(json: [String: Any]) throws {
        guard let issuerURL = json["credential_issuer"] as? String,
              let formats = json["credentials"] as? [[String: Any]],
              let format = formats.first?["format"] as? String else {
            throw WalletError.invalidCredentialOffer
        }

        self.issuerURL = issuerURL
        self.tokenEndpoint = "\(issuerURL)/token"
        self.credentialEndpoint = "\(issuerURL)/credential"
        self.format = format

        if let grants = json["grants"] as? [String: Any],
           let preAuth = grants["urn:ietf:params:oauth:grant-type:pre-authorized_code"] as? [String: Any],
           let code = preAuth["pre-authorized_code"] as? String {
            self.preAuthorizedCode = code
        } else {
            self.preAuthorizedCode = nil
        }
    }
}

struct CredentialResponse {
    let credential: String
    let expiresAt: Date?
    let metadata: [String: Any]
}

struct PresentationRequest {
    let clientId: String
    let nonce: String
    let responseURI: String
    let presentationDefinition: [String: Any]

    init(json: [String: Any]) throws {
        guard let clientId = json["client_id"] as? String,
              let nonce = json["nonce"] as? String,
              let responseURI = json["response_uri"] as? String else {
            throw WalletError.invalidPresentationRequest
        }

        self.clientId = clientId
        self.nonce = nonce
        self.responseURI = responseURI
        self.presentationDefinition = json["presentation_definition"] as? [String: Any] ?? [:]
    }
}

enum WalletError: Error {
    case storageInitializationFailed
    case keyGenerationFailed(Error?)
    case keyRetrievalFailed(OSStatus)
    case keyDeletionFailed(OSStatus)
    case keyNotFound
    case publicKeyExtractionFailed
    case publicKeyExportFailed(Error?)
    case accessControlCreationFailed(Error?)
    case didNotFound
    case invalidCredentialOffer
    case invalidPresentationRequest
    case tokenRequestFailed
    case invalidTokenResponse
    case credentialRequestFailed
    case invalidCredentialResponse
    case presentationSubmissionFailed
    case jwtSigningFailed
    case invalidJWT
}

// MARK: - Extensions

extension Data {
    func base58EncodedString() -> String {
        // Simplified base58 encoding
        // In production, use a proper base58 library
        return self.base64EncodedString()
    }

    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while base64.count % 4 != 0 {
            base64.append("=")
        }

        self.init(base64Encoded: base64)
    }
}
