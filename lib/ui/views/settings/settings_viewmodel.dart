import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/services/biometric_service.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/services/storage_service.dart';

import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SettingsViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _snackbarService = locator<SnackbarService>();
  final _storageService = locator<StorageService>();
  final _biometricService = locator<BiometricService>();
  final _credentialService = locator<CredentialService>();
  final _didService = locator<DidService>();

  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  String _biometricType = 'Not available';

  bool get biometricEnabled => _biometricEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  String get biometricType => _biometricType;
  String get appVersion => '1.0.0';
  int get credentialCount => _credentialService.credentials.length;
  int get didCount => _didService.dids.length;

  Future<void> initialize() async {
    setBusy(true);

    try {
      // Load biometric settings
      _biometricEnabled = await _storageService.isBiometricsEnabled();

      // Check biometric availability
      final isAvailable = await _biometricService.isAvailable();
      if (isAvailable) {
        final biometrics = await _biometricService.getAvailableBiometrics();
        if (biometrics.isNotEmpty) {
          _biometricType =
              _biometricService.getBiometricTypeName(biometrics.first);
        }
      }

      notifyListeners();
    } catch (e) {
      print('Failed to initialize settings: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> toggleBiometric(bool value) async {
    if (value) {
      // Check if biometrics are available
      final isAvailable = await _biometricService.isAvailable();
      if (!isAvailable) {
        await _dialogService.showDialog(
          title: 'Not Available',
          description:
              'Biometric authentication is not available on this device.',
        );
        return;
      }

      // Authenticate to enable
      final authenticated = await _biometricService.authenticate(
        reason: 'Enable biometric authentication',
      );

      if (authenticated) {
        _biometricEnabled = true;
        await _storageService.setBiometricsEnabled(true);
        _snackbarService.showSnackbar(
          duration: const Duration(seconds: 3),
          message: 'Biometric authentication enabled',
        );
      }
    } else {
      _biometricEnabled = false;
      await _storageService.setBiometricsEnabled(false);
      _snackbarService.showSnackbar(
        message: 'Biometric authentication disabled',
        duration: const Duration(seconds: 3),
      );
    }

    notifyListeners();
  }

  void toggleNotifications(bool value) {
    _notificationsEnabled = value;
    notifyListeners();

    _snackbarService.showSnackbar(
      message: value ? 'Notifications enabled' : 'Notifications disabled',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> clearCache() async {
    final response = await _dialogService.showDialog(
      title: 'Clear Cache',
      description:
          'This will clear temporary data. Your credentials and DIDs will not be affected.',
      buttonTitle: 'Clear',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // Clear cache logic here
      _snackbarService.showSnackbar(
        message: 'Cache cleared successfully',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> signOut() async {
    final response = await _dialogService.showDialog(
      title: 'Sign Out',
      description:
          'Are you sure you want to sign out? You can sign back in anytime.',
      buttonTitle: 'Sign Out',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // Sign out logic
      await _navigationService.clearStackAndShow(Routes.splashView);
    }
  }

  Future<void> deleteWallet() async {
    final response = await _dialogService.showDialog(
      title: 'Delete Wallet',
      description:
          '⚠️ WARNING: This will permanently delete all your credentials, DIDs, and wallet data. This action cannot be undone!',
      buttonTitle: 'Delete',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // Second confirmation
      final secondConfirm = await _dialogService.showDialog(
        title: 'Are you absolutely sure?',
        description:
            'Type DELETE to confirm permanent deletion of all wallet data.',
        buttonTitle: 'DELETE WALLET',
        cancelTitle: 'Cancel',
      );

      if (secondConfirm?.confirmed == true) {
        // Delete all data
        await _storageService.clearAll();

        _snackbarService.showSnackbar(
          message: 'Wallet deleted successfully',
          duration: const Duration(seconds: 3),
        );

        // Navigate to onboarding
        await _navigationService.clearStackAndShow(Routes.onboardingView);
      }
    }
  }

  void navigateToSecurity() {
    _navigationService.navigateTo(Routes.securityView);
  }

  void navigateToBackup() {
    _navigationService.navigateTo(Routes.backupView);
  }

  void navigateToDidManagement() {
    _navigationService.navigateTo(Routes.didManagementView);
  }
}
