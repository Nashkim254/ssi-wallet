# iOS EUDI Wallet Kit Integration Guide

## Overview

This guide provides step-by-step instructions for integrating the official EUDI Wallet Kit SDK into your Flutter iOS app. The integration has been prepared and is ready for you to complete.

## Current Status

✅ **Completed:**
- Podfile configured with instructions 
- EudiSsiApiImpl rewritten to support real SDK
- Info.plist configured for OAuth deep links
- Setup script created
- Documentation prepared

⏳ **Pending:**
- Add EUDI Wallet Kit via Swift Package Manager in Xcode
- Uncomment SDK integration code
- Test OAuth flow

## Prerequisites

- macOS with Xcode 15.0 or later
- CocoaPods installed
- iOS deployment target: 16.0+
- Flutter SDK

## Integration Steps

### Step 1: Run the Setup Script

We've created an automated setup script to guide you through the process:

```bash
cd /path/to/your/ssi/project
./setup_ios_sdk.sh
```

The script will:
- Check your Xcode installation
- Verify the workspace exists
- Provide detailed instructions for adding the SDK
- Guide you through enabling the SDK in code

### Step 2: Add EUDI Wallet Kit via Xcode

The EUDI Wallet Kit must be added via Swift Package Manager in Xcode:

1. **Open the workspace:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **In Xcode:**
   - Select the `Runner` project in the Project Navigator (left sidebar)
   - Select the `Runner` target
   - Click on the "Package Dependencies" tab
   - Click the "+" button at the bottom

3. **Add the package:**
   - In the search field, enter:
     ```
     https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit.git
     ```
   - Select "Exact Version" and enter: `0.19.4`
     (Or use "Up to Next Major" for automatic updates)
   - Click "Add Package"

4. **Choose package products:**
   - Check "EudiWalletKit"
   - Add to target: "Runner"
   - Click "Add Package"

5. **Wait for integration:**
   - Xcode will download and integrate the package
   - This may take a few minutes

### Step 3: Enable SDK in Code

After adding the package, enable it in your implementation:

1. **Open:** `ios/Runner/EudiSsiApiImpl.swift`

2. **Uncomment the import** (line 5):
   ```swift
   // Change this:
   // import EudiWalletKit

   // To this:
   import EudiWalletKit
   ```

3. **Enable real initialization** in the `initialize()` method:
   - Find the comment: `// TODO: After adding EudiWalletKit via SPM, replace this with real initialization:`
   - Uncomment the code block below it (lines ~27-44)
   - Comment out or remove the temporary mock initialization (lines ~46-51)

4. **Enable credential issuance** in `acceptCredentialOffer()`:
   - Find the comment: `// TODO: After SDK integration, implement real credential issuance:`
   - Uncomment the implementation code (lines ~182-221)
   - Remove the temporary mock error throw (lines ~223-228)

5. **Enable credential fetching** in `getCredentials()`:
   - Find the comment: `// TODO: After SDK integration, use real credential fetching:`
   - Uncomment the implementation code (lines ~143-152)
   - Remove the temporary empty return (line ~155)

6. **Uncomment helper method** at the bottom:
   - Find: `// TODO: Implement after SDK integration`
   - Uncomment the `documentToCredentialDto()` method (lines ~405-423)

### Step 4: Configure the SDK

The SDK is configured in the `initialize()` method. Default configuration:

```swift
let config = OpenId4VciConfiguration(
    credentialIssuerURL: "https://issuer.eudiw.dev",
    clientId: "wallet-dev",
    authFlowRedirectionURI: URL(string: "eudi-openid4ci://authorize")!,
    usePAR: true,
    useDpopIfSupported: true
)

let wallet = try EudiWallet(
    serviceName: "com.example.ssi.eudi.wallet",
    trustedReaderCertificates: [],
    userAuthenticationRequired: false,
    openID4VciConfigurations: ["issuer.eudiw.dev": config]
)
```

**To add more issuers**, add additional configurations:

```swift
var configs: [String: OpenId4VciConfiguration] = [:]

// Production issuer
configs["issuer.eudiw.dev"] = OpenId4VciConfiguration(
    credentialIssuerURL: "https://issuer.eudiw.dev",
    clientId: "wallet-dev",
    authFlowRedirectionURI: URL(string: "eudi-openid4ci://authorize")!,
    usePAR: true,
    useDpopIfSupported: true
)

// Development issuer
configs["dev.issuer.eudiw.dev"] = OpenId4VciConfiguration(
    credentialIssuerURL: "https://dev.issuer.eudiw.dev",
    clientId: "wallet-dev",
    authFlowRedirectionURI: URL(string: "eudi-openid4ci://authorize")!,
    usePAR: true,
    useDpopIfSupported: true
)

let wallet = try EudiWallet(
    serviceName: "com.example.ssi.eudi.wallet",
    trustedReaderCertificates: [],
    userAuthenticationRequired: false,
    openID4VciConfigurations: configs
)
```

### Step 5: Build and Test

```bash
# Clean and rebuild
flutter clean
cd ios
pod install
cd ..

# Build and run
flutter run
```

## OAuth Flow on iOS

With the real EUDI iOS SDK, OAuth works automatically via ASWebAuthenticationSession:

### How It Works

```swift
// 1. Flutter calls acceptCredentialOffer
let credential = try await acceptCredentialOffer(offerId: "openid-credential-offer://...")

// 2. SDK internally processes the offer
let offeredModel = try await wallet.resolveOfferUrlDocTypes(offerUri: offerId)

// 3. If authorization is required, SDK automatically:
//    - Opens ASWebAuthenticationSession (in-app browser)
//    - User completes authorization
//    - Browser redirects to: eudi-openid4ci://authorize?code=...
//    - ASWebAuthenticationSession captures the callback automatically
//    - SDK continues credential issuance

// 4. Method returns with issued credential
let documents = try await wallet.issueDocumentsByOfferUrl(
    offerUri: offerId,
    docTypes: docTypes,
    txCodeValue: nil
)

// 5. Credential is returned to Flutter
```

### No Manual Callback Handling Needed!

Unlike Android, iOS doesn't require manual callback handling because:

1. **ASWebAuthenticationSession** is integrated into the SDK
2. The authorization is handled within the SDK's async/await flow
3. The SDK automatically captures the callback URL
4. The `await` completes when OAuth is done

### Deep Link Configuration

Already configured in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.example.ssi.eudi-openid4ci</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>eudi-openid4ci</string>
        </array>
    </dict>
</array>
```

This allows the SDK's ASWebAuthenticationSession to receive callbacks at:
```
eudi-openid4ci://authorize?code=...
```

## Testing

### 1. Test SDK Initialization

```dart
final result = await ssiApi.initialize();
print('Initialized: ${result.success}');
print('Version: ${result.data?['version']}');
```

Expected output (after SDK integration):
```
Initialized: true
Version: EUDI Wallet iOS SDK v0.19.4
```

### 2. Test Credential Issuance

```dart
try {
  final credential = await ssiApi.acceptCredentialOffer(
    'openid-credential-offer://...',
    null,
  );

  print('Credential issued: ${credential?.id}');
  print('Credential name: ${credential?.name}');
} catch (e) {
  print('Error: $e');
}
```

The SDK will:
1. Parse the credential offer
2. Open ASWebAuthenticationSession if authorization needed
3. Handle OAuth automatically
4. Return the issued credential

### 3. Test Credential Retrieval

```dart
final credentials = await ssiApi.getCredentials();
print('Found ${credentials.length} credentials');
for (var cred in credentials) {
  print('- ${cred.name} (${cred.id})');
}
```

## Troubleshooting

### Package not found

**Problem:** Xcode can't find the package
**Solution:**
- Check the URL is correct
- Ensure you have internet connection
- Try clearing SPM cache: File → Swift Packages → Reset Package Caches

### Build errors after adding SDK

**Problem:** Build fails with Swift errors
**Solution:**
- Ensure you uncommented all TODO sections
- Check iOS deployment target is 16.0+
- Clean build folder: Product → Clean Build Folder
- Try: `flutter clean && cd ios && pod install && cd ..`

### OAuth not working

**Problem:** Authorization flow doesn't start
**Solution:**
- Verify Info.plist has CFBundleURLTypes configured
- Check the redirect URI matches: `eudi-openid4ci://authorize`
- Ensure the issuer supports the configured client_id

### ASWebAuthenticationSession not showing

**Problem:** Browser doesn't open for authorization
**Solution:**
- The SDK handles this automatically
- Check console logs for errors
- Verify the credential offer requires authorization
- Some offers use pre-authorized flow (no OAuth needed)

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                    │
│  ┌───────────────────────────────────────────────────┐  │
│  │            App UI & Business Logic                │  │
│  └──────────────────────┬────────────────────────────┘  │
│                         │ Pigeon API                     │
│                         ▼                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │              EudiSsiApiImpl (Swift)               │  │
│  │  - Initialize wallet with configuration           │  │
│  │  - Accept credential offers                       │  │
│  │  - Manage credentials                             │  │
│  └──────────────────────┬────────────────────────────┘  │
│                         │                                │
│                         ▼                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │         EudiWalletKit SDK (Swift Package)         │  │
│  │  - OpenID4VCI protocol implementation             │  │
│  │  - ASWebAuthenticationSession integration         │  │
│  │  - Secure credential storage                      │  │
│  │  - Document management                            │  │
│  └──────────────────────┬────────────────────────────┘  │
│                         │                                │
│                         ▼                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │          iOS Security Services                    │  │
│  │  - Secure Enclave                                 │  │
│  │  - Keychain                                       │  │
│  │  - File system (encrypted)                        │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Comparison with EUDI iOS Prototype

| Component | Your Implementation | EUDI Prototype | Status |
|-----------|---------------------|----------------|---------|
| SDK Import | `import EudiWalletKit` | `import EudiWalletKit` | ✅ Same |
| Wallet Init | `EudiWallet(...)` | `EudiWallet(...)` | ✅ Same |
| Configuration | `OpenId4VciConfiguration` | `OpenId4VciConfiguration` | ✅ Same |
| Credential Issuance | `issueDocumentsByOfferUrl()` | `issueDocumentsByOfferUrl()` | ✅ Same |
| OAuth Handling | Automatic (ASWebAuthenticationSession) | Automatic (ASWebAuthenticationSession) | ✅ Same |
| Storage | `wallet.storage.docModels` | `wallet.storage.docModels` | ✅ Same |

Your implementation matches the EUDI prototype patterns! 🎉

## Security Considerations

### Secure Storage

The EUDI SDK stores credentials in:
- **Secure Enclave**: Private keys (on devices that support it)
- **Keychain**: Credentials and sensitive data
- **File System**: Encrypted document storage

### Best Practices

1. **Don't log sensitive data**: Avoid logging credentials, keys, or personal information
2. **Use biometric authentication**: Enable `userAuthenticationRequired: true` for production
3. **Validate issuers**: Only accept credentials from trusted issuers
4. **Check certificate trust**: Configure `trustedReaderCertificates` for presentation verification

## Next Steps

1. ✅ Complete the SDK integration (Steps 1-5 above)
2. Test credential issuance with a real EUDI issuer
3. Integrate with your Flutter UI using the examples in `docs/FLUTTER_OAUTH_INTEGRATION.md`
4. Implement error handling and user feedback
5. Test on physical devices (iOS 16.0+)
6. Enable biometric authentication for production

## Resources

- **EUDI iOS SDK**: https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit
- **EUDI iOS Reference Wallet**: https://github.com/eu-digital-identity-wallet/eudi-app-ios-wallet-ui
- **SDK Documentation**: https://eu-digital-identity-wallet.github.io/eudi-lib-ios-wallet-kit/documentation/eudiwallet
- **OpenID4VCI Spec**: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review console logs for error messages
3. Verify your configuration matches the examples
4. Consult the EUDI SDK documentation
5. Check the EUDI community forums

## Changelog

- **2025-02-03**: Initial iOS SDK integration prepared
  - Created EudiSsiApiImpl with SDK support
  - Configured OAuth deep links
  - Added setup script and documentation
  - Ready for SDK integration
