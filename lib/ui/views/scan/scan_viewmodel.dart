import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/qr_scanner_service.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/models/presentation_request.dart';
import 'package:ssi/ui/views/credential_selection/credential_selection_view.dart';
import 'package:ssi/ui/views/presentation_consent/presentation_consent_view.dart';
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

    // Let MobileScanner widget handle permission automatically
    // It will show iOS native permission dialog on first use
    _hasPermission = true;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    // If permission was denied, just open Settings
    // User needs to manually enable camera there
    await _qrScannerService.openSettings();

    _snackbarService.showSnackbar(
      message: 'Find "Ssi" in Settings and enable Camera',
      duration: const Duration(seconds: 5),
    );
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
      // Process presentation request
      final requestDto =
          await _procivisService.processPresentationRequest(requestUrl);

      if (requestDto == null) {
        await _showError('Failed', 'Could not process presentation request');
        return;
      }

      final request = PresentationRequest.fromDto(requestDto);

      // Check if we have matching credentials
      if (request.matchingCredentialIds.isEmpty) {
        await _showError(
          'No Matching Credentials',
          'You don\'t have the required credentials to fulfill this request.',
        );
        return;
      }

      // Get matching credentials
      final matchingCredentialFutures = request.matchingCredentialIds
          .map((id) => _credentialService.getCredential(id));

      final matchingCredentials =
          (await Future.wait(matchingCredentialFutures))
              .whereType<Credential>()
              .toList();

      if (matchingCredentials.isEmpty) {
        await _showError(
          'No Matching Credentials',
          'Could not load the required credentials.',
        );
        return;
      }

      // Navigate to credential selection
      final selectedCredential = await _navigationService.navigateWithTransition(
        CredentialSelectionView(
          request: request,
          matchingCredentials: matchingCredentials,
        ),
      );

      if (selectedCredential == null) {
        // User cancelled
        await _procivisService.rejectPresentationRequest(request.interactionId);
        return;
      }

      // Navigate to consent screen
      final selectedClaims = await _navigationService.navigateWithTransition(
        PresentationConsentView(
          request: request,
          selectedCredential: selectedCredential,
        ),
      );

      if (selectedClaims == null || selectedClaims is! List<String>) {
        // User declined
        await _procivisService.rejectPresentationRequest(request.interactionId);
        return;
      }

      // Submit presentation
      final submission = PresentationSubmission(
        interactionId: request.interactionId,
        credentialId: selectedCredential.id,
        selectedClaims: selectedClaims,
      );

      final success =
          await _procivisService.submitPresentationWithClaims(submission.toDto());

      if (success) {
        _snackbarService.showSnackbar(
          message: 'Credentials shared successfully!',
          duration: const Duration(seconds: 3),
        );
      } else {
        await _showError('Failed', 'Could not share credentials');
      }

      navigateBack();
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
