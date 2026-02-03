# EUDI Wallet Testing Guide

## Testing with Real EUDI Test Issuer

### Official Test Issuer
**URL**: https://issuer.eudiw.dev

This is the official EU Digital Identity Wallet test issuer that supports:
- ✅ OpenID4VCI (pre-authorized code flow)
- ✅ mso_mdoc format credentials
- ✅ SD-JWT-VC format credentials
- ✅ Multiple credential types (PID, mDL, etc.)

## Step-by-Step Testing Process

### 1. Prepare Your Wallet

**Start the app:**
```bash
flutter run
```

**What happens during initialization:**
1. Wallet creates secure storage directory
2. Initializes iOS Secure Enclave
3. Loads any existing credentials
4. Sets up OpenID4VCI configuration

**Check logs for:**
```
flutter: 💡 SSI SDK initialized successfully
flutter: 💡 Loaded 0 DIDs
flutter: 💡 Loaded 0 credentials
```

### 2. Create a DID (Required for Credential Issuance)

**In the app:**
1. Navigate to **Settings** → **DID Management**
2. Tap **"+ Create New DID"**
3. Select method: **did:key** (recommended for testing)
4. Select key type: **ES256**
5. Tap **Create**

**What happens:**
- A new key pair is generated in iOS Secure Enclave
- DID document is created and stored
- DID becomes your wallet's default identity

**Expected result:**
```
DID created: did:key:z6Mk...abc123
Status: Active
Type: ES256
```

### 3. Get a Test Credential from EUDI Issuer

#### Option A: Using Test Issuer Website

1. **Visit the test issuer:**
   - Open browser: https://issuer.eudiw.dev
   - Or use the EUDI Wallet Dev Hub: https://eu-digital-identity-wallet.github.io/Test/Issuer/

2. **Generate credential offer:**
   - Select credential type (e.g., "PID - Person Identification Data")
   - Click "Generate Credential Offer"
   - A QR code will be displayed

3. **Scan with your app:**
   - In your wallet app, tap the **Scan QR Code** button (camera icon)
   - Grant camera permission if prompted
   - Point camera at the QR code
   - Wallet will detect the credential offer

#### Option B: Using Direct URL (for testing)

**Sample Credential Offer URL:**
```
openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fissuer.eudiw.dev%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22mso_mdoc%22%2C%22doctype%22%3A%22org.iso.18013.5.1.mDL%22%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22test-code-123%22%7D%7D%7D
```

**For testing, you can:**
1. Generate a QR code from this URL using any QR generator
2. Or manually trigger credential issuance in the app

### 4. Credential Issuance Flow

**What happens when you scan:**

```
[User scans QR code]
    ↓
[App detects credential offer]
    ↓
[Shows preview:]
    - Issuer: issuer.eudiw.dev
    - Type: Mobile Driving License (mDL)
    - Format: ISO mso_mdoc
    ↓
[User taps "Accept"]
    ↓
[Wallet processes offer:]
    1. Parse credential offer URL
    2. Request access token from issuer
    3. Generate proof JWT using Secure Enclave key
    4. Request credential with proof
    5. Validate and store credential
    ↓
[Success message:]
    "Credential received successfully!"
```

**Check logs during issuance:**
```
flutter: 💡 Processing QR code: openid-credential-offer://...
flutter: 💡 Receiving credential...
flutter: 💡 Credential received successfully!
```

### 5. View Stored Credentials

**In the app:**
1. Navigate to **Home** tab
2. Your credentials will be displayed as cards
3. Tap a credential to view details

**What you'll see:**
```
┌─────────────────────────────────────┐
│  Mobile Driving License              │
│                                      │
│  Issued by: Example DMV              │
│  Issued: Jan 27, 2026                │
│  Expires: Jan 27, 2027               │
│                                      │
│  Status: ✓ Valid                    │
└─────────────────────────────────────┘
```

**Credential details:**
- **ID**: Unique identifier
- **Type**: VerifiableCredential, mDL
- **Format**: ISO_MDL (mso_mdoc)
- **Issuer**: did:web:issuer.eudiw.dev
- **Holder**: Your DID (did:key:z6Mk...)
- **Claims**: Name, birth date, license number, etc.
- **Proof**: JWT signature from issuer

### 6. Where Credentials Are Stored

**iOS Storage Locations:**

1. **Secure Files** (`/Documents/eudi_wallet/`)
   - `credentials.json` - Credential data
   - `dids.json` - DID documents
   - `interactions.json` - Interaction history
   - **Protection**: FileProtectionType.completeFileProtection

2. **iOS Keychain**
   - Private keys (never leaves Secure Enclave)
   - Service: `com.example.ssi.eudi.wallet`
   - Access: When unlocked + biometric auth

3. **In-Memory Cache**
   - Active credential list
   - Current interactions
   - Cleared on app termination

**Data Structure:**
```json
{
  "id": "cred-550e8400-e29b-41d4-a716-446655440000",
  "name": "Mobile Driving License",
  "type": "VerifiableCredential",
  "format": "ISO_MDL",
  "issuerName": "Example DMV",
  "issuerDid": "did:web:issuer.eudiw.dev",
  "holderDid": "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
  "issuedDate": "2026-01-27T08:00:00Z",
  "expiryDate": "2027-01-27T08:00:00Z",
  "claims": {
    "family_name": "Doe",
    "given_name": "John",
    "birth_date": "1990-01-01",
    "document_number": "DL123456789"
  },
  "proofType": "JwtProof2020",
  "state": "valid",
  "backgroundColor": "#6366F1",
  "textColor": "#FFFFFF"
}
```

## Testing Credential Presentation

### 7. Present a Credential to a Verifier

**Using Test Verifier:**
- Visit EUDI Verifier: https://verifier.eudiw.dev (if available)
- Or use https://eu-digital-identity-wallet.github.io/Test/Verifier/

**Presentation Flow:**

1. **Verifier generates presentation request**
   - Verifier creates QR code with request
   - Request specifies what credentials they want

2. **Scan verifier's QR code**
   - Open wallet app
   - Tap Scan button
   - Scan verifier's QR code

3. **Review request**
   ```
   ┌─────────────────────────────────────┐
   │  Presentation Request                │
   │                                      │
   │  From: Example Verifier              │
   │  Requests:                           │
   │    • Mobile Driving License          │
   │    • Age over 18                     │
   │                                      │
   │  [Share]  [Decline]                 │
   └─────────────────────────────────────┘
   ```

4. **Select credentials to share**
   - Choose which credentials to present
   - Optionally select specific attributes (selective disclosure)

5. **Approve with biometrics**
   - Face ID / Touch ID authentication
   - Signs presentation with Secure Enclave key

6. **Presentation submitted**
   - Wallet creates VP token
   - Submits to verifier
   - Records interaction in history

**Check logs:**
```
flutter: 💡 Processing presentation request...
flutter: 💡 Creating VP token...
flutter: 💡 Credentials shared successfully!
```

## Testing Commands

### Start Fresh (Reset Wallet)
```bash
# Delete all app data
flutter clean
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/eudi_wallet

# Rebuild and run
flutter pub get
flutter run
```

### Debug Logging
```bash
# Run with verbose logging
flutter run --verbose

# Filter for SSI logs
flutter run 2>&1 | grep "SSI\|DID\|Credential"
```

### Test Specific Flows
```bash
# Test credential issuance only
flutter run --dart-define=TEST_MODE=issuance

# Test presentation only
flutter run --dart-define=TEST_MODE=presentation
```

## Sample Test Credentials

### 1. Mobile Driving License (mDL)
**Format**: ISO 18013-5 mso_mdoc
**Attributes**:
- Family name
- Given name
- Birth date
- Issue date
- Expiry date
- Issuing country
- Document number
- Driving privileges

### 2. Person Identification Data (PID)
**Format**: SD-JWT-VC
**Attributes**:
- Family name
- Given name
- Birth date
- Age over 18
- Nationality
- Address

### 3. European Health Insurance Card
**Format**: SD-JWT-VC
**Attributes**:
- Cardholder name
- Personal identification number
- Issuing member state
- Expiry date

## Troubleshooting

### Issue: QR Code Not Scanning
**Solution:**
1. Check camera permissions in Settings → Privacy → Camera
2. Ensure good lighting
3. Hold phone steady, 10-15cm from QR code
4. Try regenerating QR code from issuer

### Issue: "Cannot find type 'EudiSsiApiImpl'" Build Error
**Solution:**
```bash
python3 add_swift_files_to_xcode.py
flutter clean
flutter pub get
flutter run
```

### Issue: "Credential offer invalid"
**Solution:**
1. Check internet connection
2. Verify issuer URL is accessible
3. Check if credential offer is expired
4. Generate new credential offer from issuer

### Issue: "Key generation failed"
**Solution:**
1. Ensure device has Secure Enclave (iPhone 5s or later)
2. Check device has passcode enabled
3. Grant biometric permission
4. Restart app

### Issue: Credentials not displaying
**Solution:**
1. Check logs for storage errors
2. Verify file permissions
3. Check `~/Library/.../Documents/eudi_wallet/credentials.json`
4. Try restarting app

## Expected Test Results

### ✅ Successful Test Checklist

- [ ] App starts without errors
- [ ] Can create DID with Secure Enclave
- [ ] Can scan QR codes
- [ ] Can receive credential from test issuer
- [ ] Credential appears in wallet list
- [ ] Can view credential details
- [ ] Can present credential to verifier
- [ ] Biometric authentication works
- [ ] Interaction history recorded
- [ ] Can delete credentials
- [ ] Data persists after app restart

### Performance Benchmarks

| Operation | Expected Time |
|-----------|---------------|
| App startup | < 2 seconds |
| DID creation | < 1 second |
| QR code scan | < 500ms |
| Credential issuance | 2-5 seconds |
| Credential presentation | 1-3 seconds |
| Biometric auth | < 1 second |

## Next Steps After Testing

1. **Integrate with production issuers**
   - Update issuer URLs in configuration
   - Add production certificates

2. **Customize UI**
   - Brand colors and logos
   - Custom credential card designs
   - Localization

3. **Add analytics**
   - Track user flows
   - Monitor errors
   - Performance metrics

4. **Prepare for App Store**
   - Add privacy policy
   - Configure signing
   - Create screenshots
   - Submit for review

## Support

- **EUDI Documentation**: https://eu-digital-identity-wallet.github.io
- **Test Issuer**: https://issuer.eudiw.dev
- **OpenID4VCI Spec**: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html
- **OpenID4VP Spec**: https://openid.net/specs/openid-4-verifiable-presentations-1_0.html

---

**Ready to test?** Run `flutter run` and start scanning!
