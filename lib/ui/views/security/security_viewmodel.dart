import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/biometric_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SecurityViewModel extends BaseViewModel {
  final _biometricService = locator<BiometricService>();
  final _storageService = locator<StorageService>();
  final _dialogService = locator<DialogService>();
  final _snackbarService = locator<SnackbarService>();

  bool _biometricEnabled = false;
  bool _hasPinSet = false;
  String _biometricType = 'Not available';
  int _autoLockMinutes = 5;
  bool _screenshotProtectionEnabled = false;
  bool _screenRecordingAlertEnabled = true;
  bool _requireAuthForSharing = true;

  bool get biometricEnabled => _biometricEnabled;
  bool get hasPinSet => _hasPinSet;
  String get biometricType => _biometricType;
  int get autoLockMinutes => _autoLockMinutes;
  bool get screenshotProtectionEnabled => _screenshotProtectionEnabled;
  bool get screenRecordingAlertEnabled => _screenRecordingAlertEnabled;
  bool get requireAuthForSharing => _requireAuthForSharing;

  Future<void> initialize() async {
    setBusy(true);

    try {
      // Load biometric settings
      _biometricEnabled = await _storageService.isBiometricsEnabled();
      _hasPinSet = await _storageService.hasPinSet();

      // Check biometric availability
      final isAvailable = await _biometricService.isAvailable();
      if (isAvailable) {
        final biometrics = await _biometricService.getAvailableBiometrics();
        if (biometrics.isNotEmpty) {
          _biometricType =
              _biometricService.getBiometricTypeName(biometrics.first);
        }
      }

      // Load other settings from storage
      _autoLockMinutes = _storageService.getInt('auto_lock_minutes') ?? 5;
      _screenshotProtectionEnabled =
          _storageService.getBool('screenshot_protection') ?? false;
      _screenRecordingAlertEnabled =
          _storageService.getBool('screen_recording_alert') ?? true;
      _requireAuthForSharing =
          _storageService.getBool('require_auth_sharing') ?? true;

      notifyListeners();
    } catch (e) {
      print('Failed to initialize security: $e');
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
          message: 'Biometric authentication enabled',
          duration: const Duration(seconds: 3),
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

  Future<void> setupPin() async {
    final response = await _dialogService.showDialog(
      title: 'Set Security PIN',
      description: 'Enter a 6-digit PIN to secure your wallet',
      buttonTitle: 'Continue',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // In a real implementation, show PIN entry dialog
      _snackbarService.showSnackbar(
        message: 'PIN setup feature coming soon',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> changePin() async {
    // Authenticate first
    final authenticated = _biometricEnabled
        ? await _biometricService.authenticate(
            reason: 'Authenticate to change PIN')
        : true;

    if (!authenticated) return;

    final response = await _dialogService.showDialog(
      title: 'Change PIN',
      description: 'Enter your current PIN, then your new PIN',
      buttonTitle: 'Continue',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // In a real implementation, show PIN change flow
      _snackbarService.showSnackbar(
        message: 'PIN change feature coming soon',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> changeAutoLockDuration() async {
    final durations = [1, 2, 5, 10, 15, 30];

    // Show duration selection dialog
    final response = await _dialogService.showDialog(
      title: 'Auto-Lock Duration',
      description:
          'Choose when the app should auto-lock.\n\nAvailable: ${durations.join(", ")} minutes',
      buttonTitle: 'Save',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // In a real implementation, get selected duration
      // For now, just toggle between common values
      final currentIndex = durations.indexOf(_autoLockMinutes);
      final nextIndex = (currentIndex + 1) % durations.length;
      _autoLockMinutes = durations[nextIndex];

      await _storageService.setInt('auto_lock_minutes', _autoLockMinutes);
      notifyListeners();

      _snackbarService.showSnackbar(
        message: 'Auto-lock set to $_autoLockMinutes minutes',
        duration: const Duration(seconds: 3),
      );
    }
  }

  void toggleScreenshotProtection(bool value) {
    _screenshotProtectionEnabled = value;
    _storageService.setBool('screenshot_protection', value);
    notifyListeners();

    _snackbarService.showSnackbar(
      duration: const Duration(seconds: 3),
      message: value
          ? 'Screenshot protection enabled'
          : 'Screenshot protection disabled',
    );
  }

  void toggleScreenRecordingAlert(bool value) {
    _screenRecordingAlertEnabled = value;
    _storageService.setBool('screen_recording_alert', value);
    notifyListeners();

    _snackbarService.showSnackbar(
      duration: const Duration(seconds: 3),
      message: value
          ? 'Screen recording alerts enabled'
          : 'Screen recording alerts disabled',
    );
  }

  void toggleRequireAuthForSharing(bool value) {
    _requireAuthForSharing = value;
    _storageService.setBool('require_auth_sharing', value);
    notifyListeners();

    _snackbarService.showSnackbar(
      duration: const Duration(seconds: 3),
      message: value
          ? 'Authentication required for sharing'
          : 'Authentication not required for sharing',
    );
  }
}
