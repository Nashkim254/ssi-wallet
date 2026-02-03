import 'dart:async'; // Import for StreamSubscription
import 'package:app_links/app_links.dart'; // Import for AppLinks
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/pigeon/ssi_api.g.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SplashViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _procivisService = locator<ProcivisService>();
  final _storageService = locator<StorageService>();
  final _didService = locator<DidService>();
  final _credentialService = locator<CredentialService>();
  final _ssiApi = SsiApi();
  final AppLinks _appLinks = AppLinks(); // AppLinks instance
  StreamSubscription? _linkSubscription; // StreamSubscription for deep links

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Cancel subscription to prevent memory leaks
    super.dispose();
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      // Wait for minimum splash screen time for better UX
      await Future.delayed(const Duration(seconds: 2));

      // Check if app has been initialized before
      final isFirstLaunch = await _storageService.isFirstLaunch();

      // Initialize Procivis SDK if not already initialized
      if (!_procivisService.isInitialized) {
        await _procivisService.initialize();
      }

      // Initialize DID and Credential services (loads from cache, then syncs)
      await Future.wait([
        _didService.initialize(),
        _credentialService.initialize(),
      ]);

      // --- Deep Link Handling ---
      // 1. Check for initial deep link (when app is launched via deep link)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('Initial deep link: $initialUri');
        await _handleDeepLink(initialUri);
        return; // Exit if deep link handled
      }

      // 2. Listen for subsequent deep links (when app is already running)
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
        print('Stream deep link: $uri');
        await _handleDeepLink(uri);
      });
      // --- End Deep Link Handling ---

      // Navigate based on launch state if no deep link was handled
      if (isFirstLaunch) {
        await _navigationService.replaceWith(Routes.onboardingView);
      } else {
        await _navigationService.replaceWith(Routes.homeView);
      }
    } catch (e) {
      // Handle initialization errors
      print('Splash initialization error: $e');
      // Still navigate to onboarding or show error
      await _navigationService.replaceWith(Routes.onboardingView);
    } finally {
      setBusy(false);
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Example: haip-vci://credential_offer?credential_offer=...
    if (uri.scheme == 'eudi-openid4ci' && uri.host == 'authorize') {
      // This is the authorization callback from the EUDI issuer
      print('Authorization callback received: $uri');
      print('Code: ${uri.queryParameters['code']?.substring(0, 20)}...');
      print('State: ${uri.queryParameters['state']}');

      final dialogService = locator<DialogService>();
      final snackbarService = locator<SnackbarService>();

      // Show loading dialog
      dialogService.showDialog(
        title: 'Processing Credential',
        description: 'Completing credential issuance...\nThis may take a few seconds.',
        barrierDismissible: false,
      );

      try {
        // Pass the authorization response to the native SDK
        print('Passing authorization callback to native SDK...');
        final success = await _ssiApi.handleAuthorizationCallback(uri.toString());

        if (success) {
          print('Authorization callback handled successfully by native SDK');

          // Wait for token exchange and credential issuance to complete
          print('Waiting for credential issuance to complete...');
          await Future.delayed(const Duration(seconds: 3));

          // Refresh credentials to check if new credential was issued
          print('Refreshing credentials...');
          final initialCount = _credentialService.credentials.length;
          await _credentialService.loadCredentials();
          final finalCount = _credentialService.credentials.length;

          // Close loading dialog
          _navigationService.back();

          if (finalCount > initialCount) {
            print('SUCCESS: New credential received! Count: $initialCount -> $finalCount');
            snackbarService.showSnackbar(
              message: '✓ Credential received successfully!',
              duration: const Duration(seconds: 3),
            );
          } else {
            print('WARNING: No new credential found after authorization. Count: $finalCount');
            await dialogService.showDialog(
              title: 'Credential Status',
              description: 'Authorization completed, but no credential was received yet. '
                  'The credential may still be processing. Check back in a moment.',
              buttonTitle: 'OK',
            );
          }
        } else {
          // Close loading dialog
          _navigationService.back();

          print('Authorization callback failed - SDK may have lost state due to app restart');
          await dialogService.showDialog(
            title: 'Issuance Interrupted',
            description: 'The credential issuance process was interrupted. '
                'This can happen if the app was restarted during authorization.\n\n'
                'Please scan the QR code again to restart the process.',
            buttonTitle: 'OK',
          );
        }
      } catch (e) {
        // Close loading dialog
        _navigationService.back();

        print('Error handling authorization callback: $e');
        await dialogService.showDialog(
          title: 'Error',
          description: 'Failed to process credential authorization:\n\n${e.toString()}',
          buttonTitle: 'OK',
        );
      }

      await _navigationService.replaceWith(Routes.homeView);
    } else if (uri.scheme == 'haip-vci' && uri.host == 'credential_offer') {
      // This is the initial QR scan URI, contains the full offer URL
      final fullOfferUrl = uri.toString();
      print('Processing initial credential offer from QR: $fullOfferUrl');
      await _credentialService.acceptOffer(fullOfferUrl);
      await _navigationService.replaceWith(Routes.homeView);
    }
    // Add more deep link handling logic as needed
    else {
      print('Unhandled deep link: $uri');
      await _navigationService.replaceWith(Routes.homeView); // Fallback
    }
  }
}
