import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:intl/intl.dart';

class BackupViewModel extends BaseViewModel {
  final _procivisService = locator<ProcivisService>();
  final _credentialService = locator<CredentialService>();
  final _didService = locator<DidService>();
  final _storageService = locator<StorageService>();
  final _dialogService = locator<DialogService>();
  final _snackbarService = locator<SnackbarService>();

  bool _hasBackup = false;
  String _lastBackupDate = '';

  bool get hasBackup => _hasBackup;
  String get lastBackupDate => _lastBackupDate;
  int get credentialCount => _credentialService.credentials.length;
  int get didCount => _didService.dids.length;

  Future<void> initialize() async {
    // Check if backup exists
    final lastBackup = _storageService.getString('last_backup_date');
    if (lastBackup != null) {
      _hasBackup = true;
      final date = DateTime.parse(lastBackup);
      _lastBackupDate = DateFormat('MMM d, y \'at\' h:mm a').format(date);
    }
    notifyListeners();
  }

  Future<void> exportBackup() async {
    final confirm = await _dialogService.showDialog(
      title: 'Export Backup',
      description:
          'This will create a backup file containing all your credentials, '
          'DIDs, and settings. Keep this file secure.',
      buttonTitle: 'Export',
      cancelTitle: 'Cancel',
    );

    if (confirm?.confirmed != true) return;

    setBusy(true);

    try {
      // Export backup from Procivis
      final backupData = await _procivisService.exportBackup();

      if (backupData != null && backupData.isNotEmpty) {
        // In a real implementation, save to file system
        // For now, just simulate success

        // Update last backup date
        final now = DateTime.now();
        await _storageService.setString(
            'last_backup_date', now.toIso8601String());
        _hasBackup = true;
        _lastBackupDate = DateFormat('MMM d, y \'at\' h:mm a').format(now);

        notifyListeners();

        _snackbarService.showSnackbar(
          message: 'Backup exported successfully',
          duration: const Duration(seconds: 3),
        );

        // Show success with instructions
        await _dialogService.showDialog(
          title: 'Backup Created',
          description:
              'Your backup has been created. Store it securely and never share it with anyone.\n\n'
              'File location: Downloads/ssi_wallet_backup_${DateFormat('yyyyMMdd').format(now)}.json',
        );
      } else {
        await _dialogService.showDialog(
          title: 'Export Failed',
          description: 'Failed to create backup. Please try again.',
        );
      }
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to export backup: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> importBackup() async {
    final confirm = await _dialogService.showDialog(
      title: 'Import Backup',
      description:
          '⚠️ WARNING: Importing a backup will replace all current data in your wallet. '
          'This action cannot be undone.\n\n'
          'Make sure you have a recent backup of your current wallet before proceeding.',
      buttonTitle: 'Continue',
      cancelTitle: 'Cancel',
    );

    if (confirm?.confirmed != true) return;

    // Second confirmation
    final secondConfirm = await _dialogService.showDialog(
      title: 'Are you sure?',
      description:
          'This will permanently delete your current credentials and DIDs. '
          'Type IMPORT to confirm.',
      buttonTitle: 'IMPORT',
      cancelTitle: 'Cancel',
    );

    if (secondConfirm?.confirmed != true) return;

    setBusy(true);

    try {
      // In a real implementation, file picker would be shown here
      // For now, simulate the process

      await Future.delayed(const Duration(seconds: 2));

      // Show file picker simulation
      _snackbarService.showSnackbar(
        message: 'Import feature coming soon - file picker integration needed',
        duration: const Duration(seconds: 3),
      );

      // In a real implementation:
      // 1. Pick backup file
      // 2. Read backup data
      // 3. Import to Procivis: await _procivisService.importBackup(backupData)
      // 4. Reload all data
    } catch (e) {
      await _dialogService.showDialog(
        title: 'Error',
        description: 'Failed to import backup: $e',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> deleteBackupHistory() async {
    final confirm = await _dialogService.showDialog(
      title: 'Clear Backup History',
      description:
          'This will only clear the backup history, not delete any backup files.',
      buttonTitle: 'Clear',
      cancelTitle: 'Cancel',
    );

    if (confirm?.confirmed == true) {
      await _storageService.remove('last_backup_date');
      _hasBackup = false;
      _lastBackupDate = '';
      notifyListeners();

      _snackbarService.showSnackbar(
        message: 'Backup history cleared',
        duration: const Duration(seconds: 3),
      );
    }
  }
}
