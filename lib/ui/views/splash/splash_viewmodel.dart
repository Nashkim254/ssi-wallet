import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
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

      // Navigate based on launch state
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
}
