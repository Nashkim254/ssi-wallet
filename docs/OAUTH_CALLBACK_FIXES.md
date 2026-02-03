# OAuth Callback Fixes - SSI EUDI Wallet Integration

## Summary

Fixed OAuth callback handling issues in both Android and iOS implementations by aligning them with the EUDI open source prototype patterns.

## Key Issues Identified and Fixed

### Android (✅ Fully Fixed)

#### Previous Issues:
1. **MainActivity intercepting callbacks**: MainActivity.onNewIntent was trying to handle OAuth authorization callbacks directly, which prevented proper state management in the UI layer
2. **Improper flow**: Callbacks need to flow through Flutter → Native, not be intercepted at the Activity level

#### Fixes Applied:
1. **MainActivity.kt** - Removed direct OAuth callback handling
   - Authorization callbacks now flow through Flutter's app_links
   - Flutter will call `handleAuthorizationCallback()` via Pigeon when needed
   - This allows proper UI state management (loading dialogs, error messages)

2. **EudiSsiApiImpl.kt** - Already correctly implemented
   - ✅ Stores `activeOpenId4VciManager` for callback handling
   - ✅ Implements `handleAuthorizationCallback()` which calls `manager.resumeWithAuthorization(uri)`
   - ✅ Uses event-based callbacks (`IssueEvent.DocumentIssued`, `IssueEvent.Finished`, etc.)
   - ✅ Handles app state loss gracefully with error messages

#### How Android OAuth Flow Works (Aligned with EUDI Prototype):

```
1. User initiates credential offer
2. acceptCredentialOffer() called
3. Creates OpenId4VciManager and stores it
4. Calls issueDocumentByOfferUri()
5. SDK opens browser for authorization
6. User authorizes in browser
7. Browser redirects to: eudi-openid4ci://authorize?code=...
8. Flutter's app_links receives deep link
9. Flutter calls handleAuthorizationCallback() via Pigeon
10. Native calls manager.resumeWithAuthorization(uri)
11. SDK exchanges code for token
12. SDK completes credential issuance
13. IssueEvent.Finished callback fired
14. Credential returned to Flutter
```

### iOS (⚠️ Partially Fixed - Mock Implementation)

#### Previous Issues:
1. **AppDelegate intercepting callbacks**: Similar to Android, callbacks were being intercepted too early
2. **Mock wallet implementation**: Uses custom `EudiWalletCore` instead of official EUDI iOS SDK
3. **No real OAuth flow**: The mock implementation doesn't actually perform OAuth

#### Fixes Applied:
1. **AppDelegate.swift** - Removed direct OAuth callback handling
   - Callbacks now flow through Flutter's app_links
   - Added documentation explaining iOS SDK behavior

2. **EudiSsiApiImpl.swift** - Cleaned up and documented
   - Simplified `handleAuthorizationCallback()` with clear documentation
   - Removed unused `handleAuthorizationResponse()` method
   - Added warnings that mock implementation doesn't support OAuth

#### iOS Production Requirements:

To enable proper OAuth on iOS, you need to:

1. **Replace EudiWalletCore with official EUDI iOS SDK**
   - Use `EudiWallet` from the official EU Digital Identity Wallet SDK
   - Reference: See EUDI iOS prototype at `/Users/value8/work/rnd/eudi-app-ios-wallet-ui`

2. **Implement async/await pattern**
   ```swift
   // Official SDK pattern (from prototype)
   let documents = try await wallet.issueDocumentsByOfferUrl(
       offerUri: offerUri,
       docTypes: docTypes,
       txCodeValue: txCodeValue
   )
   ```

3. **No manual callback handling needed**
   - The official iOS SDK uses ASWebAuthenticationSession
   - OAuth callbacks are handled automatically by the SDK
   - The async function completes when OAuth finishes
   - No need to manually call resumeWithAuthorization

## Files Modified

### Android:
- ✅ `android/app/src/main/kotlin/com/example/ssi/MainActivity.kt`
  - Removed OAuth callback interception
  - Simplified to let Flutter handle deep links

### iOS:
- ✅ `ios/Runner/AppDelegate.swift`
  - Removed OAuth callback interception
  - Added documentation

- ✅ `ios/Runner/EudiSsiApiImpl.swift`
  - Cleaned up authorization callback handlers
  - Added production implementation guidance

## Testing Recommendations

### Android (Ready for Testing):
1. Test credential issuance flow with real EUDI issuer
2. Verify authorization browser opens correctly
3. Confirm callback is received in Flutter layer
4. Check that `handleAuthorizationCallback()` is called via Pigeon
5. Verify credential is issued successfully
6. Test error cases (denied authorization, network errors)

### iOS (Requires SDK Integration):
1. First, integrate official EUDI iOS SDK
2. Replace `EudiWalletCore` with `EudiWallet`
3. Update `acceptCredentialOffer()` to use async/await pattern
4. Then test OAuth flow

## Flutter Integration Requirements

Your Flutter app needs to:

1. **Handle deep links** using `app_links` or `uni_links` package
   ```dart
   final appLinks = AppLinks();
   appLinks.uriLinkStream.listen((uri) {
     if (uri.scheme == 'eudi-openid4ci' && uri.host == 'authorize') {
       // Call native handler via Pigeon
       await ssiApi.handleAuthorizationCallback(uri.toString());
     }
   });
   ```

2. **Manage UI state** during OAuth flow
   - Show loading indicator when opening browser
   - Handle success/failure states
   - Update UI when credential is received

3. **Configure deep link scheme** in Android and iOS
   - Already configured as `eudi-openid4ci://authorize`
   - Ensure Flutter app is set up to receive these links

## Architecture Alignment

The fixes align your implementation with the EUDI prototypes:

| Component | Android (Your Implementation) | Android (EUDI Prototype) | Status |
|-----------|------------------------------|-------------------------|---------|
| Deep link handling | Flutter app_links → Pigeon | Navigation system → ViewModel | ✅ Similar pattern |
| OAuth resume | `manager.resumeWithAuthorization()` | `walletCoreDocumentsController.resumeOpenId4VciWithAuthorization()` | ✅ Same SDK API |
| State management | Store active manager | Store managers in map | ✅ Correct approach |
| Event callbacks | `OnIssueEvent` interface | `OnIssueEvent` interface | ✅ Same pattern |

| Component | iOS (Your Implementation) | iOS (EUDI Prototype) | Status |
|-----------|--------------------------|---------------------|---------|
| Wallet SDK | Mock `EudiWalletCore` | Official `EudiWallet` | ⚠️ Needs replacement |
| OAuth handling | Manual callback attempt | Automatic via SDK | ⚠️ Needs SDK integration |
| Issuance pattern | Mock credentials | `async/await issueDocumentsByOfferUrl` | ⚠️ Needs update |

## Next Steps

1. **For Android**: Test the OAuth flow end-to-end with a real issuer
2. **For iOS**:
   - Integrate official EUDI iOS SDK
   - Implement async/await credential issuance pattern
   - Remove mock `EudiWalletCore` implementation

## References

- Android EUDI prototype: `/Users/value8/work/rnd/eudi-app-android-wallet-ui`
  - Key files: `EudiComponentActivity.kt`, `DocumentOfferViewModel.kt`, `WalletCoreDocumentsController.kt`

- iOS EUDI prototype: `/Users/value8/work/rnd/eudi-app-ios-wallet-ui`
  - Key files: `WalletKitController.swift`, `DocumentOfferViewModel.swift`

- Official EUDI Wallet SDKs:
  - Android: https://github.com/eu-digital-identity-wallet/eudi-lib-android-wallet-core
  - iOS: https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit
