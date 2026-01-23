import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/ui/models/did.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:flutter/services.dart';

class DidManagementViewModel extends BaseViewModel {
  final _didService = locator<DidService>();
  final _dialogService = locator<DialogService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _snackbarService = locator<SnackbarService>();

  List<Did> get dids => _didService.dids;

  Did? get defaultDid {
    return dids.firstWhere(
      (did) => did.isDefault,
      orElse: () => dids.isNotEmpty ? dids.first : null as Did,
    );
  }

  List<Did> get otherDids {
    return dids.where((did) => !did.isDefault).toList();
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      await _didService.loadDids();
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to load DIDs: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> refresh() async {
    await _didService.loadDids();
    notifyListeners();
  }

  Future<void> showCreateDidDialog() async {
    final methods = await _didService.getSupportedMethods();

    String? selectedMethod = methods.isNotEmpty ? methods.first : 'did:key';
    String? selectedKeyType = 'ES256';

    final response = await _dialogService.showDialog(
      title: 'Create New DID',
      description: 'Choose the DID method and key type.\n\nMethod: $selectedMethod\nKey Type: $selectedKeyType',
      buttonTitle: 'Create',
      cancelTitle: 'Cancel',
    );

    if (response?.confirmed == true) {
      await createDid(
        method: selectedMethod ?? 'did:key',
        keyType: selectedKeyType ?? 'ES256',
      );
    }
  }

  Future<void> createDid({
    required String method,
    required String keyType,
  }) async {
    setBusy(true);

    try {
      final did = await _didService.createDid(
        method: method,
        keyType: keyType,
      );

      if (did != null) {
        _snackbarService.showSnackbar(
          message: 'DID created successfully!',
          duration: const Duration(seconds: 3),
        );

        // Ask if this should be the default DID
        if (dids.length > 1) {
          final makeDefault = await _dialogService.showDialog(
            title: 'Set as Default?',
            description: 'Would you like to set this as your default DID?',
            buttonTitle: 'Yes',
            cancelTitle: 'No',
          );

          if (makeDefault?.confirmed == true) {
            await _didService.setDefaultDid(did.id);
            await refresh();
          }
        }
      } else {
        await _dialogService.showDialog(
          title: 'Error',
          description: 'Failed to create DID',
        );
      }
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to create DID: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> showDidDetails(Did did) async {
    // Show DID details
    final defaultText = did.isDefault ? ' (Default)' : '';

    final action = await _dialogService.showDialog(
      title: 'DID Details$defaultText',
      description: '${did.didString}\n\nMethod: ${did.method}\nKey Type: ${did.keyType}',
      buttonTitle: 'Copy DID',
      cancelTitle: 'Close',
    );

    if (action?.confirmed == true) {
      await copyDidToClipboard(did.didString);
    }
  }

  Future<void> copyDidToClipboard(String didString) async {
    await Clipboard.setData(ClipboardData(text: didString));
    _snackbarService.showSnackbar(
      message: 'DID copied to clipboard',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> setAsDefaultDid(Did did) async {
    setBusy(true);

    try {
      await _didService.setDefaultDid(did.id);
      await refresh();

      _snackbarService.showSnackbar(
        message: 'Default DID updated',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to set default DID: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> deleteDid(Did did) async {
    if (did.isDefault) {
      await _dialogService.showDialog(
        title: 'Cannot Delete',
        description:
            'Cannot delete the default DID. Please set another DID as default first.',
      );
      return;
    }

    final confirm = await _dialogService.showDialog(
      title: 'Delete DID',
      description:
          'Are you sure you want to delete this DID? This action cannot be undone.',
      buttonTitle: 'Delete',
      cancelTitle: 'Cancel',
    );

    if (confirm?.confirmed == true) {
      setBusy(true);

      try {
        final success = await _didService.deleteDid(did.id);

        if (success) {
          await refresh();
          _snackbarService.showSnackbar(
            message: 'DID deleted successfully',
            duration: const Duration(seconds: 3),
          );
        } else {
          await _dialogService.showDialog(
            title: 'Error',
            description: 'Failed to delete DID',
          );
        }
      } catch (e) {
        await _dialogService.showDialog(
          title: 'Error',
          description: 'Failed to delete DID: $e',
        );
      } finally {
        setBusy(false);
      }
    }
  }

  Future<void> showDidInfo() async {
    await _dialogService.showDialog(
      title: 'About DIDs',
      description:
          'Decentralized Identifiers (DIDs) are unique identifiers that enable verifiable, '
          'self-sovereign digital identity. Unlike traditional usernames or email addresses, '
          'DIDs are owned and controlled entirely by you.\n\n'
          'Your wallet can have multiple DIDs for different purposes, but one is set as default.',
    );
  }
}
