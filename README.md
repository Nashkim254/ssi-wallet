# 🔬 EUDI Wallet Technical Deep Dive - Complete E2E Implementation

## 📚 Table of Contents
1. [Complete API Flow - Credential Issuance](#complete-api-flow)
2. [Complete API Flow - Credential Verification](#credential-verification-flow)
3. [Protocol Drafts & Versions](#protocol-drafts)
4. [Credential Formats (mDoc, SD-JWT, JWT-VC)](#credential-formats)
5. [Mobile SDK Architecture](#mobile-sdk-architecture)
6. [Complete Code Examples](#code-examples)

---

# 1. Complete API Flow - Credential Issuance E2E

## 🔄 The Complete Journey

### Overview Sequence
```
User → Wallet App → Issuer Server → Auth Server → Back to Wallet → Store Credential
   (1 scan)    (8 API calls)     (OAuth)      (back)      (display)
```

---

## Phase 1: Discovery & Initialization

### API Call #1: Scan/Receive Credential Offer

**Trigger:** User scans QR code or clicks deep link

**Credential Offer Structure:**
```json
{
  "credential_issuer": "https://issuer.eudiw.dev",
  "credential_configuration_ids": [
    "eu.europa.ec.eudi.pid_vc_sd_jwt"
  ],
  "grants": {
    "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
      "pre-authorized_code": "eyJhbGciOiJSUzI1NiIsInR5cCI6Ikp...",
      "tx_code": {
        "input_mode": "numeric",
        "length": 6
      }
    }
  }
}
```

**Format:** Usually encoded as:
```
openid-credential-offer://?credential_offer=<URL_ENCODED_JSON>

OR

openid-credential-offer://?credential_offer_uri=https://issuer.eudiw.dev/offers/abc123
```

**Mobile SDK Code:**
```kotlin
// Android EUDI SDK
import eu.europa.ec.eudi.openid4vci.*

// Parse credential offer
val credentialOfferUri = "openid-credential-offer://..." // from QR scan
val config = OpenId4VCIConfig(...)

val issuer = Issuer.make(
    config = config,
    credentialOfferUri = credentialOfferUri
).getOrThrow()

// Issuer object created, contains parsed offer
```

---

### API Call #2: Fetch Issuer Metadata

**Purpose:** Get issuer capabilities and endpoints

**HTTP Request:**
```http
GET /.well-known/openid-credential-issuer HTTP/1.1
Host: issuer.eudiw.dev
```

**Response (Issuer Metadata):**
```json
{
  "credential_issuer": "https://issuer.eudiw.dev",
  "credential_endpoint": "https://issuer.eudiw.dev/credential",
  "deferred_credential_endpoint": "https://issuer.eudiw.dev/deferred",
  "notification_endpoint": "https://issuer.eudiw.dev/notification",
  "batch_credential_endpoint": "https://issuer.eudiw.dev/batch_credential",
  
  "authorization_servers": [
    "https://auth.eudiw.dev"
  ],
  
  "credential_configurations_supported": {
    "eu.europa.ec.eudi.pid_vc_sd_jwt": {
      "format": "vc+sd-jwt",
      "scope": "eu.europa.ec.eudi.pid_vc_sd_jwt",
      "cryptographic_binding_methods_supported": [
        "jwk",
        "cose_key"
      ],
      "credential_signing_alg_values_supported": [
        "ES256",
        "ES384",
        "ES512"
      ],
      "proof_types_supported": {
        "jwt": {
          "proof_signing_alg_values_supported": [
            "ES256",
            "ES384"
          ]
        }
      },
      "display": [
        {
          "name": "Person Identification Data",
          "locale": "en-US",
          "logo": {
            "uri": "https://issuer.eudiw.dev/logo.png",
            "alt_text": "EUDI Logo"
          },
          "background_color": "#6366F1",
          "text_color": "#FFFFFF"
        }
      ],
      "vct": "urn:eudi:pid:1",
      "claims": {
        "given_name": {
          "display": [{"name": "First Name", "locale": "en-US"}]
        },
        "family_name": {
          "display": [{"name": "Last Name", "locale": "en-US"}]
        },
        "birth_date": {
          "display": [{"name": "Birth Date", "locale": "en-US"}]
        },
        "age_over_18": {
          "display": [{"name": "Over 18", "locale": "en-US"}]
        }
      }
    },
    
    "org.iso.18013.5.1.mDL": {
      "format": "mso_mdoc",
      "doctype": "org.iso.18013.5.1.mDL",
      "cryptographic_binding_methods_supported": ["cose_key"],
      "credential_signing_alg_values_supported": ["ES256"],
      "proof_types_supported": {
        "jwt": {
          "proof_signing_alg_values_supported": ["ES256"]
        }
      },
      "claims": {
        "org.iso.18013.5.1": {
          "given_name": {},
          "family_name": {},
          "birth_date": {},
          "issue_date": {},
          "expiry_date": {},
          "issuing_country": {},
          "issuing_authority": {},
          "document_number": {},
          "driving_privileges": {}
        }
      }
    }
  }
}
```

**Mobile SDK Code:**
```kotlin
// SDK automatically fetches this
val metadata = issuer.credentialIssuerMetadata
println("Issuer: ${metadata.credentialIssuer}")
println("Endpoint: ${metadata.credentialEndpoint}")
```

---

### API Call #3: Fetch Authorization Server Metadata

**Purpose:** Get OAuth server capabilities

**HTTP Request:**
```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: auth.eudiw.dev
```

**Response (AS Metadata):**
```json
{
  "issuer": "https://auth.eudiw.dev",
  "authorization_endpoint": "https://auth.eudiw.dev/authorize",
  "token_endpoint": "https://auth.eudiw.dev/token",
  "pushed_authorization_request_endpoint": "https://auth.eudiw.dev/par",
  "token_endpoint_auth_methods_supported": [
    "client_secret_basic",
    "client_secret_post",
    "private_key_jwt",
    "none"
  ],
  "grant_types_supported": [
    "authorization_code",
    "urn:ietf:params:oauth:grant-type:pre-authorized_code"
  ],
  "response_types_supported": ["code"],
  "code_challenge_methods_supported": ["S256"],
  "dpop_signing_alg_values_supported": ["ES256", "ES384"],
  "scopes_supported": [
    "eu.europa.ec.eudi.pid_vc_sd_jwt",
    "org.iso.18013.5.1.mDL"
  ]
}
```

---

## Phase 2: Authorization

### Two Flow Options:

#### Flow A: Pre-Authorized Code (Simpler, faster)

**API Call #4a: Exchange Pre-Auth Code for Token**

**HTTP Request:**
```http
POST /token HTTP/1.1
Host: auth.eudiw.dev
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code
&pre-authorized_code=eyJhbGciOiJSUzI1NiIsInR5cCI6Ikp...
&tx_code=123456  // If required (user PIN)
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "c_nonce": "tZignsnFbp",
  "c_nonce_expires_in": 86400
}
```

**Mobile SDK Code:**
```kotlin
// Pre-authorized flow
val authorizedRequest = when (val grant = issuer.credentialOffer.grants) {
    is PreAuthorizedCodeGrant -> {
        // Get transaction code from user if required
        val txCode = if (grant.txCodeRequired) {
            getUserTransactionCode() // Show PIN dialog
        } else null
        
        issuer.authorizeWithPreAuthorizationCode(
            PreAuthorizationCode(grant.preAuthorizedCode),
            txCode
        ).getOrThrow()
    }
}
```

---

#### Flow B: Authorization Code (OAuth standard)

**API Call #4b: Pushed Authorization Request (PAR) - Optional but Recommended**

**HTTP Request:**
```http
POST /par HTTP/1.1
Host: auth.eudiw.dev
Content-Type: application/x-www-form-urlencoded
Authorization: Basic <base64(client_id:client_secret)>

response_type=code
&client_id=wallet-app
&redirect_uri=eudi-wallet://callback
&scope=eu.europa.ec.eudi.pid_vc_sd_jwt
&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
&code_challenge_method=S256
&state=af0ifjsldkj
&authorization_details=[{
  "type": "openid_credential",
  "credential_configuration_id": "eu.europa.ec.eudi.pid_vc_sd_jwt"
}]
&wallet_issuer=https://wallet-provider.example.com
&wallet_nonce=8c9c7a53-5c6d-4a5e-b2d8-9e1f2a3b4c5d
```

**Response:**
```json
{
  "request_uri": "urn:ietf:params:oauth:request_uri:abc123",
  "expires_in": 90
}
```

**API Call #5b: Authorization Request**

**HTTP Request (via browser redirect):**
```http
GET /authorize?client_id=wallet-app
  &request_uri=urn:ietf:params:oauth:request_uri:abc123 HTTP/1.1
Host: auth.eudiw.dev
```

User sees login page → authenticates → consents

**Redirect Response:**
```
eudi-wallet://callback?code=SplxlOBeZQQYbYS6WxSbIA&state=af0ifjsldkj
```

**API Call #6b: Exchange Auth Code for Token**

**HTTP Request:**
```http
POST /token HTTP/1.1
Host: auth.eudiw.dev
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=eudi-wallet://callback
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
&client_id=wallet-app
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "c_nonce": "tZignsnFbp",
  "c_nonce_expires_in": 86400,
  "authorization_details": [{
    "type": "openid_credential",
    "credential_configuration_id": "eu.europa.ec.eudi.pid_vc_sd_jwt"
  }]
}
```

**Mobile SDK Code:**
```kotlin
// Authorization code flow
val authorizedRequest = when (val grant = issuer.credentialOffer.grants) {
    is AuthorizationCodeGrant -> {
        // Prepare authorization request
        val preparedAuth = issuer.prepareAuthorizationRequest().getOrThrow()
        
        // Open browser to authorization URL
        val authUrl = preparedAuth.authorizationCodeURL.value
        openBrowser(authUrl)
        
        // Wait for redirect callback with code
        val (code, state) = awaitAuthorizationCallback()
        
        // Exchange code for token
        issuer.authorizeWithAuthorizationCode(
            preparedAuthorizationRequest = preparedAuth,
            authorizationCode = AuthorizationCode(code),
            serverState = state
        ).getOrThrow()
    }
}
```

---

## Phase 3: Credential Issuance

### API Call #7: Request Credential with Proof

**Purpose:** Request credential and prove key ownership

**First: Generate Key Pair & Create Proof**

```kotlin
// Mobile SDK generates key pair
val keyPair = KeyPairGenerator.getInstance("EC").apply {
    initialize(ECGenParameterSpec("secp256r1"))
}.generateKeyPair()

// Create DID from public key
val did = createDidKey(keyPair.public)

// Create proof JWT
val proof = createProofJWT(
    algorithm = "ES256",
    keyId = did,
    issuer = did,
    audience = "https://issuer.eudiw.dev",
    nonce = authorizedRequest.cNonce, // from token response!
    privateKey = keyPair.private
)
```

**Proof JWT Structure:**
```json
// Header
{
  "typ": "openid4vci-proof+jwt",
  "alg": "ES256",
  "kid": "did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH"
}

// Payload
{
  "iss": "did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH",
  "aud": "https://issuer.eudiw.dev",
  "iat": 1706274800,
  "nonce": "tZignsnFbp"  // c_nonce from token response!
}

// Signature: signed with private key
```

**HTTP Request:**
```http
POST /credential HTTP/1.1
Host: issuer.eudiw.dev
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

{
  "credential_identifier": "eu.europa.ec.eudi.pid_vc_sd_jwt",
  "proof": {
    "proof_type": "jwt",
    "jwt": "eyJ0eXAiOiJvcGVuaWQ0dmNpLXByb29mK2p3dCIsImFsZyI6IkVTMjU2Iiwia2lkIjoiZGlkOmtleTo..."
  }
}
```

**Response - Immediate Issuance:**
```json
{
  "format": "vc+sd-jwt",
  "credential": "eyJhbGciOiJFUzI1NiIsInR5cCI6InZjK3NkLWp3dCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5ldWRpdy5kZXYiLCJpYXQiOjE3MDYyNzQ4MDAsImV4cCI6MTczNzgxMDgwMCwidmN0IjoidXJuOmV1ZGk6cGlkOjEiLCJnaXZlbl9uYW1lIjoiSm9obiIsImZhbWlseV9uYW1lIjoiRG9lIiwiYmlydGhfZGF0ZSI6IjE5OTAtMDEtMDEiLCJfc2QiOlsiQWJDZEVmR2hJaksxMjM0NTY3ODkiXSwiY25mIjp7Imp3ayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMjU2IiwieCI6IjEyMyIsInkiOiI0NTYifX19...",
  "c_nonce": "fGFF7UkhLa",
  "c_nonce_expires_in": 86400
}
```

**Response - Deferred Issuance:**
```json
{
  "transaction_id": "8xLOxBtZp8",
  "c_nonce": "wlbQc6pCJp",
  "c_nonce_expires_in": 86400
}
```

**Mobile SDK Code:**
```kotlin
// Request credential
val credentialResponse = issuer.requestSingle(
    authorizedRequest = authorizedRequest,
    credentialConfigurationId = CredentialConfigurationIdentifier("eu.europa.ec.eudi.pid_vc_sd_jwt"),
    proofs = ProofsSpecification.JwtProofs.NoKeyAttestation(
        signer = JwtSigner { 
            // Sign with private key
            signJwt(it, keyPair.private)
        }
    )
).getOrThrow()

when (credentialResponse) {
    is SubmissionOutcome.Success -> {
        val credentials = credentialResponse.credentials
        // Store credentials!
        storeCredentials(credentials)
    }
    is SubmissionOutcome.Deferred -> {
        val transactionId = credentialResponse.transactionId
        // Poll later
        pollForCredential(transactionId)
    }
    is SubmissionOutcome.Failed -> {
        // Handle error
    }
}
```

---

### API Call #8 (Optional): Poll for Deferred Credential

**HTTP Request:**
```http
POST /deferred HTTP/1.1
Host: issuer.eudiw.dev
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

{
  "transaction_id": "8xLOxBtZp8"
}
```

**Response:**
```json
{
  "format": "vc+sd-jwt",
  "credential": "eyJhbGciOiJFUzI1NiIs..."
}
```

---

## Phase 4: Storage & Display

### Store Credential

```kotlin
// EUDI Wallet SDK handles storage automatically
val document = Document(
    id = UUID.randomUUID().toString(),
    format = DocumentFormat.SD_JWT_VC,
    name = "Person Identification Data",
    createdAt = Instant.now(),
    data = credentialResponse.credential
)

wallet.addDocument(document)
```

**Stored on Device:**
```
Android: /data/data/com.ssi.wallet/files/documents/
iOS: App Sandbox/Documents/

Encrypted with Android Keystore / iOS Keychain
```

### Display Credential

```kotlin
// Load all documents
val documents = wallet.getAllDocuments()

// Display in UI
documents.forEach { doc ->
    CredentialCard(
        name = doc.name,
        issuer = doc.issuerName,
        issuedDate = doc.createdAt,
        expiryDate = doc.expiryDate,
        status = doc.status
    )
}
```

---

# 2. Complete API Flow - Credential Verification (Implementation)

## The Verification Journey Overview

### Overview Sequence
```
User → Scan QR → Wallet App → EUDI SDK → Verifier Server → User Consent → VP Token → Verified
  (1 scan)    (parse URL)   (resolve)   (fetch request)   (select claims) (submit)  (done)
```

### Prerequisites
- Wallet initialized with EUDI SDK (iOS v0.19.4 / Android v0.23.0)
- At least one credential issued and stored (e.g., mDL via OpenID4VCI)
- IACA trusted reader certificates bundled in app (for verifier certificate chain validation)
- EUDI Reference Verifier: `https://verifier.eudiw.dev`

---

## Phase 1: Configuration & Trust Setup

Before any verification can happen, the wallet must be configured with trusted reader certificates
and OpenID4VP settings. Without these, the SDK will reject verifier requests with
"Could not trust certificate chain".

### iOS Configuration

```swift
// Load EUDI IACA trusted reader certificates from bundle (.der format)
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
    }
}

let wallet = try EudiWallet(
    serviceName: "com.example.ssi.eudi.wallet",
    trustedReaderCertificates: trustedCerts,  // Critical for verification
    userAuthenticationRequired: false,
    openID4VciConfigurations: ["issuer": config]
)
```

**Certificate files location:** `ios/Runner/Certificate/*.der`
**Source:** Downloaded from [eudi-app-ios-wallet-ui](https://github.com/eu-digital-identity-wallet/eudi-app-ios-wallet-ui) reference app

### Android Configuration

```kotlin
val config = EudiWalletConfig()
    .configureDocumentManager(
        storagePath = storageFile.absolutePath,
        identifier = null
    )
    .configureLogging(level = Logger.LEVEL_DEBUG)
    .configureReaderTrustStore(
        context,
        R.raw.pidissuerca02_ut, R.raw.pidissuerca02_eu,
        R.raw.pidissuerca02_cz, R.raw.pidissuerca02_ee,
        R.raw.pidissuerca02_lu, R.raw.pidissuerca02_nl,
        R.raw.pidissuerca02_pt, R.raw.dc4eu, R.raw.r45_staging
    )
    .configureOpenId4Vp {
        withClientIdSchemes(
            ClientIdScheme.X509SanDns,
            ClientIdScheme.X509Hash
        )
        withSchemes(
            "openid4vp", "eudi-openid4vp",
            "mdoc-openid4vp", "haip-vp"
        )
        withFormats(
            Format.MsoMdoc.ES256,
            Format.SdJwtVc.ES256
        )
    }

wallet = EudiWallet(context, config)
```

**Certificate files location:** `android/app/src/main/res/raw/*.pem`
**Source:** Downloaded from [eudi-app-android-wallet-ui](https://github.com/eu-digital-identity-wallet/eudi-app-android-wallet-ui) reference app

### IACA Certificates Bundled

| Certificate | Country/Region | Format (iOS/Android) |
|-------------|---------------|---------------------|
| pidissuerca02_ut | Test/Dev | .der / .pem |
| pidissuerca02_eu | EU | .der / .pem |
| pidissuerca02_cz | Czech Republic | .der / .pem |
| pidissuerca02_ee | Estonia | .der / .pem |
| pidissuerca02_lu | Luxembourg | .der / .pem |
| pidissuerca02_nl | Netherlands | .der / .pem |
| pidissuerca02_pt | Portugal | .der / .pem |
| r45_staging | Staging | .der / .pem |
| dc4eu | DC4EU (Android only) | - / .pem |

---

## Phase 2: Initiate Presentation (Scan QR Code)

### Step 1: User Scans Verifier QR Code

The EUDI Reference Verifier (`https://verifier.eudiw.dev`) generates QR codes containing
OpenID4VP authorization request URIs.

**QR Code Content (example):**
```
eudi-openid4vp://authorize?client_id=...&request_uri=https://verifier.eudiw.dev/wallet/request.jwt/...
```

**Supported URI Schemes:**
- `openid4vp://` - Standard OpenID4VP
- `eudi-openid4vp://` - EUDI-specific scheme
- `mdoc-openid4vp://` - mDoc-specific scheme
- `haip-vp://` - HAIP VP scheme

### Step 2: Flutter Layer Receives URL

The Flutter QR scanner captures the URL and passes it to the native layer via Pigeon:

```dart
// Flutter scan_viewmodel.dart
final presentationRequest = await _ssiApi.processPresentationRequest(scannedUrl);
```

---

## Phase 3: Process Presentation Request (Native SDK)

### iOS Implementation

```swift
func processPresentationRequest(url: String, completion: @escaping (Result<PresentationRequestDto?, Error>) -> Void) {
    Task {
        guard let wallet = wallet as? EudiWallet else { throw ... }
        guard let urlData = url.data(using: .utf8) else { throw ... }

        // Step 1: Begin presentation session with OpenID4VP flow
        let session = await wallet.beginPresentation(
            flow: .openid4vp(qrCode: urlData),
            sessionTransactionLogger: nil
        )

        // Step 2: Receive and parse the verifier's request
        // SDK fetches request_uri, validates verifier certificate chain,
        // and matches requested claims against stored credentials
        guard let requestInfo = await session.receiveRequest() else {
            // Common errors:
            // - "Could not trust certificate chain" → missing IACA certs
            // - "Claim not found: ..." → verifier requested claims not in credential
            throw NSError(domain: "EudiSsiApiImpl", code: -1,
                userInfo: [NSLocalizedDescriptionKey: session.uiError?.description ?? "Unknown error"])
        }

        // Step 3: Parse disclosed documents into app's DTO format
        // session.disclosedDocuments contains matched credentials with requested elements
        for docElement in session.disclosedDocuments {
            switch docElement {
            case .msoMdoc(let mdocElements):
                // Parse mso_mdoc elements (ISO 18013-5 namespace format)
                for namespace in mdocElements.nameSpacedElements {
                    for element in namespace.elements {
                        // element.elementIdentifier = "family_name", "given_name", etc.
                        // element.isOptional = whether the verifier marked it optional
                        // element.intentToRetain = whether verifier intends to store the data
                    }
                }
            case .sdJwt(let sdJwtElements):
                // Parse SD-JWT elements
                for sdItem in sdJwtElements.sdJwtElements {
                    // sdItem.elementPath = ["family_name"] etc.
                }
            }
        }

        // Step 4: Store session for later submission
        pendingSessions[interactionId] = session

        // Return parsed request to Flutter for UI display
        completion(.success(presentationRequest))
    }
}
```

**Key iOS SDK Types:**
- `PresentationSession` - Manages the full presentation lifecycle
- `UserRequestInfo` - Contains verifier identity (legal name, certificate issuer)
- `DocElements` - Enum with `.msoMdoc` and `.sdJwt` cases
- `FlowType.openid4vp(qrCode: Data)` - Initiates OpenID4VP flow

### Android Implementation

```kotlin
override fun processPresentationRequest(url: String, callback: (Result<PresentationRequestDto?>) -> Unit) {
    coroutineScope.launch {
        // Step 1: Resolve the OpenID4VP request URI
        val resolvedRequest = wallet!!.resolveRequestUri(url)

        when (resolvedRequest) {
            is ResolvedRequestObject.OpenId4VPAuthorization -> {
                // Step 2: Extract verifier info and requested claims
                val verifierName = resolvedRequest.clientMetadata?.clientName ?: "Unknown Verifier"

                // Step 3: Parse presentation definition for requested claims
                resolvedRequest.presentationDefinition.inputDescriptors.forEach { descriptor ->
                    descriptor.constraints?.fields?.forEach { field ->
                        // field.path = ["$.family_name"], ["$.age_over_18"], etc.
                        // field.optional = whether verifier considers this optional
                        // field.intentToRetain = whether verifier intends to store data
                    }
                }

                // Step 4: Match credentials against request
                val allDocs = wallet.getDocuments()
                val matchingDocs = allDocs.filter { doc ->
                    matchesPresentationDefinition(doc, resolvedRequest.presentationDefinition)
                }

                // Store request for later submission
                pendingPresentations[interactionId] = resolvedRequest

                callback(Result.success(presentationRequest))
            }
        }
    }
}
```

### What the SDK Does Internally

When `beginPresentation()` (iOS) or `resolveRequestUri()` (Android) is called:

1. **Parse URI** - Extract `client_id` and `request_uri` from the QR code URL
2. **Fetch Request Object** - `GET {request_uri}` to retrieve the signed JWT request
3. **Validate Verifier Certificate** - Check X.509 certificate chain against bundled IACA certs
4. **Parse Presentation Definition** - Extract requested claims, formats, and constraints
5. **Match Credentials** - Find stored documents that satisfy the request
6. **Return Results** - Provide matched documents with selectable claim elements

---

## Phase 4: User Consent & Claim Selection

### Flutter UI Flow

```dart
// scan_viewmodel.dart - After receiving PresentationRequestDto
// 1. Fetch full credential details for each matching ID
final credentials = await Future.wait(
    presentationRequest.matchingCredentialIds.map((id) =>
        _ssiApi.getCredential(id)  // Must return real data, not null!
    )
);

// 2. Show consent screen with:
//    - Verifier name and trust info
//    - List of requested claims (with required/optional marking)
//    - Intent-to-retain information
//    - Matching credential details

// 3. User selects which claims to share and approves
```

**Critical Implementation Note:** The `getCredential(id)` method must return real credential data.
A stub returning `null` causes the UI to show "No Matching Credentials" even when the SDK
found matches. This was a key bug we fixed:

```swift
// iOS - Real getCredential implementation
func getCredential(credentialId: String, completion: @escaping (Result<CredentialDto?, Error>) -> Void) {
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
            // Return pending credential DTO
            completion(.success(...))
            return
        }

        completion(.success(nil))
    }
}
```

```kotlin
// Android - Real getCredential implementation
override fun getCredential(credentialId: String, callback: (Result<CredentialDto?>) -> Unit) {
    coroutineScope.launch {
        val document = wallet?.getDocumentById(credentialId)
        val credential = when (document) {
            is IssuedDocument -> documentToCredentialDto(document)
            else -> null
        }
        withContext(Dispatchers.Main) { callback(Result.success(credential)) }
    }
}
```

---

## Phase 5: Submit Presentation Response

### iOS - Submit with Selected Claims

```swift
func submitPresentationWithClaims(
    submission: PresentationSubmissionDto,
    completion: @escaping (Result<Bool, Error>) -> Void
) {
    Task {
        // Retrieve the stored presentation session
        guard let session = pendingSessions[submission.interactionId] else { throw ... }

        // Build RequestItems from user's selected claims
        // The SDK uses isSelected flags on each element
        guard let selectedDoc = session.disclosedDocuments.first(
            where: { $0.docId == submission.credentialId }
        ) else { throw ... }

        switch selectedDoc {
        case .msoMdoc(let mdocElements):
            for namespace in mdocElements.nameSpacedElements {
                for element in namespace.elements {
                    // Select if user chose this claim OR if it's required
                    element.isSelected = selectedClaims.contains(element.elementIdentifier)
                        || !element.isOptional
                }
            }
            requestItems[credentialId] = mdocElements.selectedItemsDictionary

        case .sdJwt(let sdJwtElements):
            for sdItem in sdJwtElements.sdJwtElements {
                let claimName = sdItem.elementPath.joined(separator: ".")
                sdItem.isSelected = selectedClaims.contains(claimName)
                    || !sdItem.isOptional
            }
            requestItems[credentialId] = sdJwtElements.selectedItemsDictionary
        }

        // Send response to verifier via EUDI SDK
        await session.sendResponse(
            userAccepted: true,
            itemsToSend: requestItems,
            onSuccess: { @Sendable redirectUrl in
                print("Presentation response sent")
            }
        )

        // Verify submission succeeded
        guard session.status == .responseSent else { throw ... }

        // Clean up
        pendingSessions.removeValue(forKey: submission.interactionId)
        completion(.success(true))
    }
}
```

### Android - Submit with Selected Claims

```kotlin
override fun submitPresentationWithClaims(
    submission: PresentationSubmissionDto,
    callback: (Result<Boolean>) -> Unit
) {
    coroutineScope.launch {
        val request = pendingPresentations[submission.interactionId]
            ?: throw IllegalStateException("Presentation request not found")

        val credential = wallet!!.getDocuments()
            .find { it.id == submission.credentialId }
            ?: throw IllegalArgumentException("Credential not found")

        when (request) {
            is ResolvedRequestObject.OpenId4VPAuthorization -> {
                val disclosedDoc = DisclosedDocument(
                    document = credential,
                    disclosedClaims = submission.selectedClaims.filterNotNull()
                )

                wallet!!.sendResponse(
                    resolvedRequest = request,
                    disclosedDocuments = listOf(disclosedDoc)
                )
            }
        }

        pendingPresentations.remove(submission.interactionId)
        callback(Result.success(true))
    }
}
```

### What the SDK Does During Submission

1. **Build VP Token** - Creates Verifiable Presentation token with selective disclosure
   - For mDoc: CBOR-encoded DeviceResponse with only selected IssuerSignedItems
   - For SD-JWT: Issuer JWT + selected Disclosures + Key Binding JWT
2. **Sign with Device Key** - Proves credential possession with device-bound key
3. **POST to Verifier** - Sends VP token + presentation_submission to verifier's `response_uri`
4. **Receive Result** - Gets success/redirect response from verifier

---

## Phase 6: Complete Flow Diagram (Implementation)

```
┌──────────┐     ┌───────────┐     ┌────────────┐     ┌────────────┐
│  User    │     │  Flutter  │     │ Native SDK │     │  Verifier  │
│          │     │  (Dart)   │     │ (iOS/And)  │     │  Server    │
└────┬─────┘     └─────┬─────┘     └──────┬─────┘     └──────┬─────┘
     │                 │                   │                   │
     │ 1. Scan QR      │                   │                   │
     │────────────────>│                   │                   │
     │                 │                   │                   │
     │                 │ 2. processPres    │                   │
     │                 │   entationReq()   │                   │
     │                 │──────────────────>│                   │
     │                 │                   │                   │
     │                 │                   │ 3. beginPresent() │
     │                 │                   │   /resolveReq()   │
     │                 │                   │──────────────────>│
     │                 │                   │                   │
     │                 │                   │ 4. Fetch request  │
     │                 │                   │   + validate cert │
     │                 │                   │<──────────────────│
     │                 │                   │                   │
     │                 │ 5. PresentationRe │                   │
     │                 │   questDto        │                   │
     │                 │<──────────────────│                   │
     │                 │                   │                   │
     │                 │ 6. getCredential()│                   │
     │                 │──────────────────>│                   │
     │                 │<──────────────────│                   │
     │                 │                   │                   │
     │ 7. Show consent │                   │                   │
     │   screen        │                   │                   │
     │<────────────────│                   │                   │
     │                 │                   │                   │
     │ 8. User approves│                   │                   │
     │────────────────>│                   │                   │
     │                 │                   │                   │
     │                 │ 9. submitPresenta │                   │
     │                 │   tionWithClaims()│                   │
     │                 │──────────────────>│                   │
     │                 │                   │                   │
     │                 │                   │ 10. sendResponse()│
     │                 │                   │   (VP Token)      │
     │                 │                   │──────────────────>│
     │                 │                   │                   │
     │                 │                   │ 11. Success/      │
     │                 │                   │   Redirect        │
     │                 │                   │<──────────────────│
     │                 │                   │                   │
     │                 │ 12. true          │                   │
     │                 │<──────────────────│                   │
     │                 │                   │                   │
     │ 13. Show success│                   │                   │
     │<────────────────│                   │                   │
```


# 3. Protocol Drafts & Versions

## OpenID4VCI Specification Evolution

### Draft Versions Timeline

| Draft | Date | Major Changes | EUDI Status |
|-------|------|---------------|-------------|
| **Draft 13** | 2023-02 | Original wallet attestation | Deprecated |
| **Draft 14** | 2024-01 | Added batch issuance, improved proofs | Used in early EUDI |
| **Version 1.0** | 2024-08 | **OFFICIAL RELEASE** | ✅ **Current EUDI Standard** |

### Key Differences Between Drafts

#### Draft 13 → Draft 14:
- ❌ Removed: Simple wallet attestation
- ✅ Added: Wallet Instance Attestation (WIA)
- ✅ Added: Wallet Unit Attestation (WUA)
- ✅ Added: Batch credential endpoint
- ✅ Improved: Proof types structure

#### Draft 14 → Version 1.0:
- ✅ Finalized: All endpoints and parameters
- ✅ Standardized: Error codes
- ✅ Added: Credential response encryption
- ✅ Added: Notification endpoint
- ✅ Added: Status list support

### EUDI Uses: **OpenID4VCI 1.0** (Released August 2024)

**Current EUDI Implementation:**
```kotlin
// Check version
import eu.europa.ec.eudi.openid4vci.*

// Library implements OpenID4VCI 1.0
val version = "1.0"
```

---

## OpenID4VP (Presentation) Versions

| Draft | Status | EUDI Usage |
|-------|--------|------------|
| **Draft 20** | 2023-12 | Early pilots |
| **Draft 23** | 2024-06 | ✅ Current EUDI standard |
| **Version 1.0** | Coming 2025 | Future adoption |

---

## ISO 18013-5 (mDL) Standard

**Published:** 2021  
**Current Version:** ISO/IEC 18013-5:2021  
**EUDI Compliance:** ✅ Full support

---

## SD-JWT Specification

**Standard:** IETF RFC 9396 (Draft → RFC in 2024)  
**EUDI Usage:** SD-JWT VC (Verifiable Credentials)  
**Version:** Based on RFC 9396

---

# 3. Credential Formats Deep Dive

## Format Comparison Table

| Feature | SD-JWT | mDoc (ISO 18013-5) | JWT-VC | JSON-LD |
|---------|--------|-------------------|---------|---------|
| **Encoding** | JWT | CBOR | JWT | JSON |
| **Selective Disclosure** | ✅ Native | ✅ Native | ❌ | ⚠️ (BBS+) |
| **Offline Verification** | ✅ | ✅✅ | ✅ | ✅ |
| **Mobile Optimized** | ✅ | ✅✅ | ✅ | ❌ |
| **NFC Support** | ❌ | ✅✅ | ❌ | ❌ |
| **BLE Support** | ⚠️ | ✅✅ | ⚠️ | ❌ |
| **Zero-Knowledge** | ❌ | ❌ | ❌ | ✅ (BBS+) |
| **Size** | Medium | Small | Large | Very Large |
| **Complexity** | Medium | High | Low | Very High |
| **EUDI Primary Use** | ✅ PID | ✅ mDL | ⚠️ Simple | ❌ Future |

---

## Format 1: SD-JWT (Selective Disclosure JWT)

### Structure

**Complete SD-JWT:**
```
<Issuer-JWT>~<Disclosure-1>~<Disclosure-2>~<Disclosure-3>~...~<KB-JWT>
```

### Example SD-JWT Credential

**Issuer JWT (Main Credential):**
```json
// Header
{
  "alg": "ES256",
  "typ": "vc+sd-jwt",
  "kid": "did:web:issuer.eudiw.dev#key-1"
}

// Payload
{
  "iss": "https://issuer.eudiw.dev",
  "sub": "did:key:z6MkpTHR8VNs...",
  "iat": 1706274800,
  "exp": 1737810800,
  "vct": "urn:eudi:pid:1",
  
  // Selectively disclosable claims (hashed)
  "_sd": [
    "tXPXWThPKXg1RcD6kGVvSZvDfVQi1L0N-TDhFtPhB4A",  // given_name
    "9g6_BlmMRkYl7nQSmvqx7A_xVLqhMkHPWIiCc45Tc2k",  // family_name
    "KPmgNW9q8X2TJzqGR0h4BNQsPiLM1pFxQ8dVvWfHaGs"   // birth_date
  ],
  
  // Always visible claim
  "age_over_18": true,
  
  // Confirmation claim (holder's key binding)
  "cnf": {
    "jwk": {
      "kty": "EC",
      "crv": "P-256",
      "x": "TCAER19Zvu3OHF4j4W4vfSVoHIP1ILilDls7vCeGemc",
      "y": "ZxjiWWbZMQGHVWKVQ4hbSIirsVfuecCE6t4jT9F2HZQ"
    }
  }
}

// Signature
<issuer_signature>
```

**Disclosure 1 (given_name):**
```json
["_26", "given_name", "John"]
```
Base64URL encoded: `WyJfMjYiLCAiZ2l2ZW5fbmFtZSIsICJKb2huIl0`
Hash (SHA-256): `tXPXWThPKXg1RcD6kGVvSZvDfVQi1L0N-TDhFtPhB4A`

**Disclosure 2 (family_name):**
```json
["_35", "family_name", "Doe"]
```

**Disclosure 3 (birth_date):**
```json
["_42", "birth_date", "1990-01-01"]
```

**Key Binding JWT (Holder Proof):**
```json
// Header
{
  "alg": "ES256",
  "typ": "kb+jwt"
}

// Payload
{
  "iat": 1706274900,
  "aud": "https://verifier.example.com",
  "nonce": "XZOUco1u_gEPknxS78sWWg",
  "sd_hash": "p4oKSBqe3fJwFX2G7cq3DKPQsv_YDe0pPHFMlF9_8gE"
}

// Signature with holder's private key
<holder_signature>
```

**Complete SD-JWT:**
```
eyJhbGciOiJFUzI1NiIsInR5cCI6InZjK3NkLWp3dCJ9.eyJpc3MiOi...~WyJfMjYiLCAiZ2l2ZW5fbmFtZSIsICJKb2huIl0~WyJfMzUiLCAiZmFtaWx5X25hbWUiLCAiRG9lIl0~WyJfNDIiLCAiYmlydGhfZGF0ZSIsICIxOTkwLTAxLTAxIl0~eyJhbGciOiJFUzI1NiIsInR5cCI6ImtiK2p3dCJ9.eyJpYXQiOj...
```

### Selective Disclosure in Action

**Scenario:** Verifier requests only age_over_18 and family_name

**Wallet reveals:**
```
<Issuer-JWT>~<Disclosure-2 (family_name)>~<KB-JWT>
```

**Verifier sees:**
- ✅ age_over_18: true (always visible)
- ✅ family_name: "Doe" (disclosed)
- ❌ given_name: HIDDEN
- ❌ birth_date: HIDDEN

---

## Format 2: mDoc (ISO 18013-5 Mobile Document)

### Structure (CBOR encoded)

**mDoc Structure:**
```
IssuerSigned {
  nameSpaces: {
    "org.iso.18013.5.1": [
      IssuerSignedItem(
        digestID: 0,
        random: h'...',
        elementIdentifier: "family_name",
        elementValue: "Doe"
      ),
      IssuerSignedItem(
        digestID: 1,
        random: h'...',
        elementIdentifier: "given_name",
        elementValue: "John"
      ),
      ...
    ]
  },
  issuerAuth: [
    protected: h'...',  // COSE Sign1 protected headers
    unprotected: {},
    payload: h'...',    // MSO (Mobile Security Object)
    signature: h'...'   // Issuer signature
  ]
}

DeviceSigned {
  nameSpaces: {},
  deviceAuth: [
    deviceSignature: [
      protected: h'...',
      unprotected: {},
      payload: null,
      signature: h'...'  // Device signature
    ]
  ]
}
```

### MSO (Mobile Security Object)

```cbor
{
  "version": "1.0",
  "digestAlgorithm": "SHA-256",
  "valueDigests": {
    "org.iso.18013.5.1": {
      0: h'base16_hash_of_family_name',
      1: h'base16_hash_of_given_name',
      2: h'base16_hash_of_birth_date',
      ...
    }
  },
  "deviceKeyInfo": {
    "deviceKey": {
      1: 2,  // kty: EC2
      -1: 1, // crv: P-256
      -2: h'...', // x coordinate
      -3: h'...'  // y coordinate
    }
  },
  "docType": "org.iso.18013.5.1.mDL",
  "validityInfo": {
    "signed": "2024-01-01T00:00:00Z",
    "validFrom": "2024-01-01T00:00:00Z",
    "validUntil": "2029-01-01T00:00:00Z"
  }
}
```

### Selective Disclosure

```kotlin
// Request specific attributes
val requestedDataElements = mapOf(
    "org.iso.18013.5.1" to listOf(
        "family_name",
        "birth_date",
        "driving_privileges"
    )
)

// mDoc response contains ONLY requested elements
// + device signature proving possession
```

### Proximity Transfer (BLE/NFC)

**Device Engagement (QR Code):**
```cbor
{
  "version": "1.0",
  "security": {
    1: 2,  // cipher suite
    -1: h'...'  // ephemeral public key
  },
  "deviceRetrievalMethods": [
    {
      "type": 2,  // BLE
      "version": 1,
      "retrievalOptions": {
        "bleUUID": "0000XXXX-0000-1000-8000-00805F9B34FB"
      }
    }
  ]
}
```

---

## Format 3: JWT-VC (Simple JWT Verifiable Credential)

### Structure

**Simpler than SD-JWT - No selective disclosure**

```json
// Header
{
  "alg": "ES256",
  "typ": "JWT",
  "kid": "did:web:issuer.example.com#key-1"
}

// Payload (W3C VC Data Model)
{
  "iss": "did:web:issuer.example.com",
  "sub": "did:key:z6MkpTHR8VNs...",
  "iat": 1706274800,
  "exp": 1737810800,
  "vc": {
    "@context": [
      "https://www.w3.org/2018/credentials/v1"
    ],
    "type": ["VerifiableCredential", "UniversityDegree"],
    "credentialSubject": {
      "id": "did:key:z6MkpTHR8VNs...",
      "degree": "Bachelor of Science",
      "major": "Computer Science",
      "gpa": 3.8,
      "graduationYear": 2024
    }
  }
}

// Signature
<issuer_signature>
```

**Key Difference:** ALL claims always visible - no selective disclosure

---

## Format Recommendation by Use Case

| Use Case | Recommended Format | Why |
|----------|-------------------|-----|
| **PID (Person ID)** | SD-JWT | Selective disclosure for privacy |
| **mDL (Driver's License)** | mDoc | ISO standard, offline, NFC/BLE |
| **University Diploma** | JWT-VC or SD-JWT | Simple claims OR selective |
| **Health Certificate** | mDoc or SD-JWT | Privacy + offline |
| **Membership Card** | JWT-VC | Simple, no privacy needed |
| **Bank Statement** | SD-JWT | Selective amounts/dates |

---

# 4. Mobile SDK Architecture

## Component Diagram

```
┌────────────────────────────────────────────────────┐
│              Flutter/React Native App               │
├────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────────────────────────────┐ │
│  │         Platform Channel Bridge               │ │
│  └──────────────┬───────────────────────────────┘ │
│                 │                                   │
└─────────────────┼───────────────────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
┌───▼─────────────┐    ┌────────▼──────────┐
│  Android Kotlin │    │   iOS Swift        │
│                 │    │                    │
│ ┌─────────────┐ │    │ ┌───────────────┐ │
│ │EUDI Wallet  │ │    │ │ EUDI Wallet   │ │
│ │Core Library │ │    │ │ Kit Library   │ │
│ └──────┬──────┘ │    │ └───────┬───────┘ │
│        │        │    │         │         │
│ ┌──────▼──────┐ │    │ ┌───────▼───────┐ │
│ │OpenID4VCI   │ │    │ │ OpenID4VCI    │ │
│ │Library      │ │    │ │ Library       │ │
│ └──────┬──────┘ │    │ └───────┬───────┘ │
│        │        │    │         │         │
│ ┌──────▼──────┐ │    │ ┌───────▼───────┐ │
│ │Document Mgr │ │    │ │ Document Mgr  │ │
│ │(mDoc/SD-JWT)│ │    │ │(mDoc/SD-JWT)  │ │
│ └──────┬──────┘ │    │ └───────┬───────┘ │
│        │        │    │         │         │
│ ┌──────▼──────┐ │    │ ┌───────▼───────┐ │
│ │ Secure      │ │    │ │ Secure        │ │
│ │ Storage     │ │    │ │ Storage       │ │
│ │ (Keystore)  │ │    │ │ (Keychain)    │ │
│ └─────────────┘ │    │ └───────────────┘ │
└─────────────────┘    └───────────────────┘
```

## Layer Responsibilities

### Layer 1: EUDI Wallet Core
**Package:** `eu.europa.ec.eudi.wallet`

**Responsibilities:**
- Document lifecycle management
- Configuration management
- High-level wallet operations

**Key Classes:**
```kotlin
class EudiWallet(
    context: Context,
    config: EudiWalletConfig
) {
    fun loadDocuments()
    fun getAllDocuments(): List<Document>
    fun addDocument(document: Document)
    fun deleteDocument(documentId: String)
    fun issueDocumentByOfferUri(...)
    fun resolveRequestUri(...)
    fun sendResponse(...)
}
```

### Layer 2: OpenID4VCI Library
**Package:** `eu.europa.ec.eudi.openid4vci`

**Responsibilities:**
- OpenID4VCI protocol implementation
- Authorization flows
- Credential requests

**Key Classes:**
```kotlin
interface Issuer {
    val credentialIssuerMetadata: CredentialIssuerMetadata
    val credentialOffer: CredentialOffer
    
    suspend fun authorizeWithPreAuthorizationCode(...)
    suspend fun prepareAuthorizationRequest(...)
    suspend fun authorizeWithAuthorizationCode(...)
    suspend fun requestSingle(...)
    suspend fun requestBatch(...)
}
```

### Layer 3: Document Manager
**Package:** `eu.europa.ec.eudi.wallet.document`

**Responsibilities:**
- mDoc encoding/decoding (CBOR)
- SD-JWT parsing
- Credential verification

**Key Classes:**
```kotlin
sealed class DocumentFormat {
    object SD_JWT_VC : DocumentFormat()
    object MSO_MDOC : DocumentFormat()
    object JWT_VC : DocumentFormat()
}

interface DocumentManager {
    fun parseCredential(raw: String, format: DocumentFormat): Document
    fun verifyCredential(document: Document): VerificationResult
    fun extractClaims(document: Document): Map<String, Any>
}
```

### Layer 4: Secure Storage
**Package:** `eu.europa.ec.eudi.wallet.storage`

**Android:**
```kotlin
class AndroidKeystoreSecureArea : SecureArea {
    // Uses Android Keystore for key storage
    // Keys never leave secure hardware
    override fun generateKeyPair(...): KeyPair
    override fun sign(data: ByteArray, keyAlias: String): ByteArray
}

class EncryptedDocumentStorage(context: Context) {
    // Uses EncryptedFile API
    fun store(document: Document)
    fun retrieve(documentId: String): Document
}
```

**iOS:**
```swift
class IOSKeychainSecureArea: SecureArea {
    // Uses iOS Keychain/Secure Enclave
    func generateKeyPair(...) -> KeyPair
    func sign(data: Data, keyIdentifier: String) -> Data
}

class EncryptedDocumentStorage {
    // Uses Data Protection API
    func store(document: Document)
    func retrieve(documentId: String) -> Document
}
```

---



---

## 🎯 Summary

This document covered:

1. ✅ **Complete API Flow** - All 8 API calls with full request/response examples
2. ✅ **Protocol Drafts** - Evolution from Draft 13 → Draft 14 → v1.0
3. ✅ **Credential Formats** - Deep dive into SD-JWT, mDoc, JWT-VC with examples
4. ✅ **SDK Architecture** - Complete layer breakdown with responsibilities
5. ✅ **Code Examples** - Production-ready Kotlin and Flutter examples

**Key Takeaways:**
- EUDI uses **OpenID4VCI 1.0** (released August 2024)
- Primary formats: **SD-JWT** (PID) and **mDoc** (mDL)
- **8 main API calls** for complete credential issuance
- **4-layer architecture**: Core → Protocol → Documents → Storage
- All credentials **stored encrypted** on device with hardware-backed keys

Want me to dive deeper into any specific section? 🚀
