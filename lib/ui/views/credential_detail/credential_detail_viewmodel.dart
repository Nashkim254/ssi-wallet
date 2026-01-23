import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class CredentialDetailViewModel extends BaseViewModel {
  final String credentialId;
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _snackbarService = locator<SnackbarService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _credentialService = locator<CredentialService>();

  Credential? _credential;

  CredentialDetailViewModel({required this.credentialId});

  Credential? get credential => _credential;

  Color get cardBackgroundColor {
    if (_credential?.backgroundColor != null) {
      try {
        return Color(int.parse(
          _credential!.backgroundColor!.replaceFirst('#', '0xFF'),
        ));
      } catch (e) {
        return const Color(0xFF6366F1);
      }
    }
    return const Color(0xFF6366F1);
  }

  Color get cardTextColor {
    if (_credential?.textColor != null) {
      try {
        return Color(int.parse(
          _credential!.textColor!.replaceFirst('#', '0xFF'),
        ));
      } catch (e) {
        return Colors.white;
      }
    }
    return Colors.white;
  }

  String get formatLabel {
    if (_credential == null) return '';

    switch (_credential!.format.toLowerCase()) {
      case 'jwt':
      case 'jwt_vc':
        return 'JWT VC';
      case 'sd-jwt':
      case 'sdjwt':
        return 'SD-JWT VC';
      case 'mdoc':
      case 'iso_mdoc':
        return 'ISO mDL';
      case 'jsonld':
      case 'json-ld':
        return 'JSON-LD VC';
      default:
        return _credential!.format.toUpperCase();
    }
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      _credential = await _credentialService.getCredential(credentialId);

      if (_credential == null) {
        await _dialogService.showDialog(
          title: 'Error',
          description: 'Credential not found',
        );
        _navigationService.back();
      }
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to load credential: $e',
      );
      _navigationService.back();
    } finally {
      setBusy(false);
    }
  }

  Future<void> shareCredential() async {
    if (_credential == null) return;

    final response = await _dialogService.showDialog(
      title: 'Share Credential',
      description: 'Choose how you want to share this credential',
      buttonTitle: 'Show QR Code',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      showQRCode();
    }
  }

  Future<void> showQRCode() async {
    if (_credential == null) return;

    // Show QR code in bottom sheet
    await _bottomSheetService.showBottomSheet(
      title: 'Credential QR Code',
      description:
          'Scan this QR code to share your credential.\n\nQR Code generation coming soon!',
      // In a real implementation, generate and show QR code
    );

    _snackbarService.showSnackbar(
      message: 'QR Code feature coming soon',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> verifyCredential() async {
    if (_credential == null) return;

    setBusy(true);

    try {
      final status = await _credentialService.checkStatus(credentialId);

      String title;
      String description;

      switch (status) {
        case CredentialStatus.valid:
          title = '✓ Valid';
          description = 'This credential is valid and can be used';
          break;
        case CredentialStatus.expired:
          title = '⚠ Expired';
          description = 'This credential has expired';
          break;
        case CredentialStatus.revoked:
          title = '✕ Revoked';
          description = 'This credential has been revoked by the issuer';
          break;
        case CredentialStatus.suspended:
          title = '⏸ Suspended';
          description = 'This credential has been temporarily suspended';
          break;
        case CredentialStatus.unknown:
          title = '? Unknown';
          description = 'Could not verify credential status';
          break;
      }

      await _dialogService.showDialog(
        title: title,
        description: description,
      );
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to verify credential: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> refreshStatus() async {
    if (_credential == null) return;

    setBusy(true);

    try {
      await _credentialService.checkStatus(credentialId);

      // Reload credential
      _credential = await _credentialService.getCredential(credentialId);

      _snackbarService.showSnackbar(
        message: 'Credential status updated',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to refresh status',
        duration: const Duration(seconds: 3),
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> exportCredential() async {
    if (_credential == null) return;

    final response = await _dialogService.showDialog(
      title: 'Export Credential',
      description: 'Export this credential as a file?',
      buttonTitle: 'Export',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      // Export logic here
      _snackbarService.showSnackbar(
        message: 'Export feature coming soon',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> deleteCredential() async {
    if (_credential == null) return;

    final response = await _dialogService.showDialog(
      title: 'Delete Credential',
      description:
          'Are you sure you want to delete this credential? This action cannot be undone.',
      buttonTitle: 'Delete',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      setBusy(true);

      try {
        final success = await _credentialService.deleteCredential(credentialId);

        if (success) {
          _snackbarService.showSnackbar(
            message: 'Credential deleted successfully',
            duration: const Duration(seconds: 3),
          );
          _navigationService.back();
        } else {
          await _dialogService.showDialog(
            title: 'Error',
            description: 'Failed to delete credential',
          );
        }
      } catch (e) {
        await _dialogService.showDialog(
          title: 'Error',
          description: 'Failed to delete credential: $e',
        );
      } finally {
        setBusy(false);
      }
    }
  }

  Future<void> copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snackbarService.showSnackbar(
      message: '$label copied to clipboard',
      duration: const Duration(seconds: 3),
    );
  }

  String shortDid(String did) {
    if (did.length <= 30) return did;
    return '${did.substring(0, 15)}...${did.substring(did.length - 15)}';
  }
}
