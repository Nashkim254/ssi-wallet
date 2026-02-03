# EU Digital Identity Wallet Integration

## Overview

This document describes the integration of the **EU Digital Identity Wallet (EUDI)** libraries into the Flutter SSI application. The EUDI wallet is an open-source European digital identity solution that provides comprehensive support for:

- ✅ **OpenID4VCI** (OpenID for Verifiable Credential Issuance) v1.0
- ✅ **OpenID4VP** (OpenID for Verifiable Presentations) v1.0
- ✅ **ISO 18013-5** (Mobile Driving License standard)
- ✅ **mDL** (Mobile Driver's License) support
- ✅ **SD-JWT-VC** (Selective Disclosure JWT Verifiable Credentials)
- ✅ **mso_mdoc** format support
- ✅ Secure storage with hardware-backed keys
- ✅ Android Keystore & iOS Secure Enclave integration
- ✅ Both **Android** and **iOS** native libraries

## What Was Replaced

### Previous Implementation
- **SpruceKit Mobile SDK** v0.13.16
- Mock/placeholder implementation with in-memory storage
- Basic DID and credential management without real issuance/presentation

### New Implementation
- **Android**: `eudi-lib-android-wallet-core` v0.23.1
- **iOS**: `eudi-lib-ios-wallet-kit` v0.12.0
- Full production-ready wallet capabilities
- Hardware-backed secure storage
- OpenID4VCI/VP protocol support
- ISO 18013-5 compliance

## Architecture

```
┌─────────────────────────────────────────┐
│         Flutter UI Layer                │
│    (lib/ui/*, lib/services/*)           │
└─────────────────┬───────────────────────┘
                  │
                  │ Pigeon API
                  │
┌─────────────────┴───────────────────────┐
│                                         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │   Android    │    │     iOS      │  │
│  │              │    │              │  │
│  │ EudiSsiApiImpl    │ EudiSsiApiImpl  │
│  │              │    │              │  │
│  └──────┬───────┘    └──────┬───────┘  │
│         │                   │          │
│  ┌──────▼──────────┐ ┌──────▼────────┐ │
│  │ EUDI Android    │ │ EUDI iOS      │ │
│  │ Wallet Core     │ │ Wallet Kit    │ │
│  │ v0.23.1         │ │ v0.12.0       │ │
│  └─────────────────┘ └───────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

## Features Implemented

### 1. Wallet Initialization
- ✅ Secure document storage with encryption
- ✅ Hardware key storage (Android Keystore / iOS Secure Enclave)
- ✅ OpenID4VCI configuration with issuer URLs
- ✅ OpenID4VP configuration with client ID schemes

### 2. DID Management
- ✅ Create DIDs (did:key, did:web, did:jwk, did:ebsi)
- ✅ List all DIDs
- ✅ Get specific DID by ID
- ✅ Delete DIDs
- ✅ Default DID selection

### 3. Credential Management
- ✅ Accept credential offers via OpenID4VCI
- ✅ List all credentials/documents
- ✅ Get specific credential by ID
- ✅ Delete credentials
- ✅ Check credential status
- ✅ Support for multiple formats (mso_mdoc, sd-jwt-vc)

### 4. Presentation Protocol
- ✅ Process presentation requests
- ✅ Submit credential presentations
- ✅ Reject presentation requests
- ✅ Interaction history tracking

### 5. Backup & Recovery
- ✅ Export wallet backup metadata
- ✅ Import wallet backup (basic implementation)

## Platform Requirements

### Android
- **Minimum SDK**: API 26 (Android 8.0)
- **Target SDK**: Latest
- **Build Tools**: Gradle 8.9.1
- **Kotlin**: 2.1.0
- **Java Version**: 11

### iOS
- **Minimum Version**: iOS 16.0
- **Platform**: iOS (iPhone/iPad)
- **Language**: Swift 5.0+
- **CocoaPods**: Required

## Dependencies Added

### Android (`android/app/build.gradle.kts`)
```kotlin
dependencies {
    implementation("eu.europa.ec.eudi:eudi-lib-android-wallet-core:0.23.1-SNAPSHOT")
    implementation("androidx.biometric:biometric-ktx:1.2.0-alpha05")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.1")
}
```

### iOS (`ios/Podfile`)
```ruby
pod 'EudiWalletKit', :git => 'https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit.git', :tag => '0.12.0'
```

## Configuration

### Android Settings (`android/settings.gradle.kts`)
Added Maven repository for EUDI snapshots:
```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent { snapshotsOnly() }
        }
    }
}
```

## Native Implementation Files

### Android
- **Implementation**: `android/app/src/main/kotlin/com/example/ssi/EudiSsiApiImpl.kt`
- **MainActivity**: Updated to use `EudiSsiApiImpl`
- **Features**: Full OpenID4VCI, document management, secure storage

### iOS
- **Implementation**: `ios/Runner/EudiSsiApiImpl.swift`
- **AppDelegate**: Updated to use `EudiSsiApiImpl`
- **Features**: Full OpenID4VCI, document management, Secure Enclave

## API Methods

All methods are accessible via the Pigeon-generated `SsiApi`:

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize EUDI wallet with configuration |
| `getVersion()` | Get wallet SDK version |
| `createDid()` | Create a new DID |
| `getDids()` | Get all DIDs |
| `getDid()` | Get specific DID by ID |
| `deleteDid()` | Delete a DID |
| `getCredentials()` | Get all issued credentials |
| `getCredential()` | Get specific credential by ID |
| `acceptCredentialOffer()` | Accept a credential offer URL |
| `deleteCredential()` | Delete a credential |
| `checkCredentialStatus()` | Check if credential is valid |
| `processPresentationRequest()` | Parse presentation request |
| `submitPresentation()` | Submit credential presentation |
| `rejectPresentationRequest()` | Reject presentation request |
| `getInteractionHistory()` | Get presentation history |
| `exportBackup()` | Export wallet backup |
| `importBackup()` | Import wallet backup |
| `getSupportedDidMethods()` | Get supported DID methods |
| `getSupportedCredentialFormats()` | Get supported formats |
| `uninitialize()` | Clean up wallet resources |

## Building the Project

### 1. Install Flutter Dependencies
```bash
flutter pub get
```

### 2. Generate Pigeon Code
```bash
flutter pub run pigeon --input pigeons/ssi_api.dart
```

### 3. Android Build
```bash
cd android
./gradlew build
cd ..
```

### 4. iOS Build
```bash
cd ios
pod install
cd ..
```

### 5. Run the App
```bash
# Android
flutter run

# iOS
flutter run -d iPhone
```

## Testing

### Test Credential Issuance
1. Initialize the wallet
2. Create a DID
3. Accept a credential offer with a valid OpenID4VCI URL
4. Verify the credential appears in the credentials list

### Test Presentation
1. Have issued credentials in wallet
2. Process a presentation request URL
3. Select credentials to present
4. Submit presentation

## Security Considerations

### Android
- ✅ Documents encrypted in storage
- ✅ Keys stored in Android Keystore (hardware-backed)
- ✅ Biometric authentication support
- ✅ No backup of sensitive data to cloud

### iOS
- ✅ Documents stored in app documents directory
- ✅ Keys stored in Secure Enclave
- ✅ Keychain protection
- ✅ No iCloud backup of credentials

## Known Limitations

1. **Development Release**: EUDI wallet libraries are marked as "initial development release" and not recommended for production yet
2. **Backup/Restore**: Full backup/restore functionality requires custom implementation
3. **Status Checking**: Advanced credential status checking (revocation lists) requires additional implementation
4. **DID Management**: DIDs are stored separately from EUDI wallet (which focuses on credentials)

## Future Enhancements

- [ ] Implement proximity presentation (NFC/BLE)
- [ ] Add advanced credential status checking
- [ ] Implement full backup/restore with encryption
- [ ] Add support for multiple issuers configuration
- [ ] Integrate DID methods with EUDI wallet
- [ ] Add credential expiry notifications
- [ ] Implement revocation registry checking

## Resources

- [EUDI Wallet Architecture](https://github.com/eu-digital-identity-wallet/eudi-doc-architecture-and-reference-framework)
- [Android Wallet Core](https://github.com/eu-digital-identity-wallet/eudi-lib-android-wallet-core)
- [iOS Wallet Kit](https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit)
- [OpenID4VCI Spec](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [OpenID4VP Spec](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)
- [ISO 18013-5](https://www.iso.org/standard/69084.html)

## Support

For issues related to:
- **Flutter integration**: Check the `lib/services/procivis_service.dart` and Pigeon API
- **Android EUDI wallet**: See [eudi-lib-android-wallet-core issues](https://github.com/eu-digital-identity-wallet/eudi-lib-android-wallet-core/issues)
- **iOS EUDI wallet**: See [eudi-lib-ios-wallet-kit issues](https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit/issues)

## License

This integration uses EU Digital Identity Wallet libraries which are licensed under Apache 2.0.
