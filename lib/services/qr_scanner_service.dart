import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerService {
  final Logger _logger = Logger();

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  /// Returns true if granted, false otherwise
  /// Throws PermissionPermanentlyDeniedException if permanently denied
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;

    // If permanently denied, need to open settings
    if (status.isPermanentlyDenied) {
      _logger.w('Camera permission permanently denied');
      throw PermissionPermanentlyDeniedException();
    }

    // Request permission
    final result = await Permission.camera.request();

    // If denied after request, might be permanent now
    if (result.isPermanentlyDenied) {
      _logger.w('Camera permission permanently denied after request');
      throw PermissionPermanentlyDeniedException();
    }

    return result.isGranted;
  }

  /// Open app settings
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Process scanned QR code data
  Future<QrScanResult> processScanResult(String data) async {
    try {
      _logger.i('Processing QR code: $data');

      // Determine the type of QR code
      // EUDI/HAIP credential offer schemes
      if (data.startsWith('openid-credential-offer://') ||
          data.startsWith('haip-vci://') ||
          data.startsWith('openid4vci://')) {
        return QrScanResult(
          type: QrCodeType.credentialOffer,
          data: data,
          isValid: true,
        );
      } else if (data.startsWith('openid://') ||
          data.startsWith('haip-vp://') ||
          data.startsWith('openid4vp://')) {
        return QrScanResult(
          type: QrCodeType.presentationRequest,
          data: data,
          isValid: true,
        );
      } else if (data.startsWith('did:')) {
        return QrScanResult(
          type: QrCodeType.didConnection,
          data: data,
          isValid: true,
        );
      } else if (data.startsWith('http://') || data.startsWith('https://')) {
        // Could be a URL-based credential offer or presentation request
        if (data.contains('credential_offer') || data.contains('offer')) {
          return QrScanResult(
            type: QrCodeType.credentialOffer,
            data: data,
            isValid: true,
          );
        } else if (data.contains('presentation') || data.contains('verify')) {
          return QrScanResult(
            type: QrCodeType.presentationRequest,
            data: data,
            isValid: true,
          );
        }
      }

      // Unknown or invalid QR code
      return QrScanResult(
        type: QrCodeType.unknown,
        data: data,
        isValid: false,
        error: 'Unknown QR code format',
      );
    } catch (e) {
      _logger.e('Failed to process QR scan result: $e');
      return QrScanResult(
        type: QrCodeType.unknown,
        data: data,
        isValid: false,
        error: 'Failed to process QR code: $e',
      );
    }
  }

  /// Validate QR code URL
  bool isValidUrl(String data) {
    try {
      final uri = Uri.parse(data);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

class QrScanResult {
  final QrCodeType type;
  final String data;
  final bool isValid;
  final String? error;

  QrScanResult({
    required this.type,
    required this.data,
    required this.isValid,
    this.error,
  });

  String get displayMessage {
    switch (type) {
      case QrCodeType.credentialOffer:
        return 'Credential Offer Detected';
      case QrCodeType.presentationRequest:
        return 'Presentation Request Detected';
      case QrCodeType.didConnection:
        return 'DID Connection Detected';
      case QrCodeType.unknown:
        return error ?? 'Unknown QR Code';
    }
  }
}

enum QrCodeType {
  credentialOffer,
  presentationRequest,
  didConnection,
  unknown,
}

class PermissionPermanentlyDeniedException implements Exception {
  final String message = 'Permission permanently denied. Please enable it in Settings.';
}
