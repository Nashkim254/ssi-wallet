import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/qr_scanner_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ScanViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _qrScannerService = locator<QrScannerService>();
  final _procivisService = locator<ProcivisService>();
  final _credentialService = locator<CredentialService>();
  final _dialogService = locator<DialogService>();
  final _snackbarService = locator<SnackbarService>();

  late MobileScannerController scannerController;

  bool _hasPermission = false;
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  String _scanMessage = 'Scan QR Code';
  String _processingMessage = 'Processing...';

  bool get hasPermission => _hasPermission;
  bool get isScanning => _isScanning;
  bool get isProcessing => _isProcessing;
  bool get isFlashOn => _isFlashOn;
  String get scanMessage => _scanMessage;
  String get processingMessage => _processingMessage;

  Future<void> initialize() async {
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    // Check camera permission
    _hasPermission = await _qrScannerService.hasCameraPermission();

    if (!_hasPermission) {
      _hasPermission = await _qrScannerService.requestCameraPermission();
    }

    notifyListeners();
  }

  Future<void> requestPermission() async {
    _hasPermission = await _qrScannerService.requestCameraPermission();
    notifyListeners();
  }

  Future<void> onQRDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _isProcessing = true;
    _isScanning = false;
    notifyListeners();

    try {
      // Process the scanned QR code
      final result = await _qrScannerService.processScanResult(code);

      if (result.isValid) {
        switch (result.type) {
          case QrCodeType.credentialOffer:
            await _handleCredentialOffer(result.data);
            break;

          case QrCodeType.presentationRequest:
            await _handlePresentationRequest(result.data);
            break;

          case QrCodeType.didConnection:
            await _handleDidConnection(result.data);
            break;

          case QrCodeType.unknown:
            await _showError(
                'Unknown QR Code', result.error ?? 'Invalid QR code format');
            break;
        }
      } else {
        await _showError(
            'Invalid QR Code', result.error ?? 'Could not process QR code');
      }
    } catch (e) {
      await _showError('Error', 'Failed to process QR code: $e');
    } finally {
      _isProcessing = false;
      _isScanning = true;
      notifyListeners();
    }
  }

  Future<void> _handleCredentialOffer(String offerUrl) async {
    _processingMessage = 'Receiving credential...';
    notifyListeners();

    try {
      final credential = await _credentialService.acceptOffer(offerUrl);

      if (credential != null) {
        // Show success message
        _snackbarService.showSnackbar(
          message: 'Credential received successfully!',
          duration: const Duration(seconds: 3),
        );

        // Navigate back
        navigateBack();
      } else {
        await _showError(
          'Failed',
          'Could not receive credential. Please try again.',
        );
      }
    } catch (e) {
      await _showError('Error', 'Failed to receive credential: $e');
    }
  }

  Future<void> _handlePresentationRequest(String requestUrl) async {
    _processingMessage = 'Processing request...';
    notifyListeners();

    try {
      final result =
          await _procivisService.processPresentationRequest(requestUrl);

      if (result != null) {
        // Show credential selection dialog
        final response = await _dialogService.showDialog(
          title: 'Share Credentials',
          description:
              'A verifier is requesting your credentials. Would you like to proceed?',
          buttonTitle: 'Share',
          cancelTitle: 'Decline',
        );

        if (response?.confirmed == true) {
          // In a real implementation, show credential selection
          // For now, just navigate back
          _snackbarService.showSnackbar(
            message: 'Credentials shared successfully!',
            duration: const Duration(seconds: 3),
          );
          navigateBack();
        } else {
          // Reject the request
          await _procivisService.rejectPresentationRequest(
            result['interactionId'] as String,
          );
          navigateBack();
        }
      } else {
        await _showError('Failed', 'Could not process presentation request');
      }
    } catch (e) {
      await _showError('Error', 'Failed to process request: $e');
    }
  }

  Future<void> _handleDidConnection(String did) async {
    _processingMessage = 'Connecting...';
    notifyListeners();

    // Show connection dialog
    final response = await _dialogService.showDialog(
      title: 'DID Connection',
      description: 'Connect with this DID?\n\n$did',
      buttonTitle: 'Connect',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      _snackbarService.showSnackbar(
        message: 'Connection established!',
        duration: const Duration(seconds: 3),
      );
      navigateBack();
    }
  }

  Future<void> _showError(String title, String message) async {
    await _dialogService.showDialog(
      title: title,
      description: message,
      buttonTitle: 'OK',
    );
  }

  void toggleFlash() {
    scannerController.toggleTorch();
    _isFlashOn = !_isFlashOn;
    notifyListeners();
  }

  void navigateBack() {
    _navigationService.back();
  }

  void disposeScanner() {
    scannerController.dispose();
  }
}
