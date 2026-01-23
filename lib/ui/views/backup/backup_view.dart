import 'package:flutter/material.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:ssi/ui/views/backup/backup_viewmodel.dart';
import 'package:stacked/stacked.dart';

class BackupView extends StackedView<BackupViewModel> {
  const BackupView({super.key});

  @override
  Widget builder(
    BuildContext context,
    BackupViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Backup your wallet data securely. Keep your backup in a safe place.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.info.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Last Backup Info
          if (viewModel.hasBackup)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Backup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              viewModel.lastBackupDate,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (viewModel.hasBackup) const SizedBox(height: 24),

          // Export Backup Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: viewModel.isBusy ? null : viewModel.exportBackup,
              icon: viewModel.isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(viewModel.isBusy ? 'Exporting...' : 'Export Backup'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Import Backup Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: viewModel.isBusy ? null : viewModel.importBackup,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Import Backup'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Backup Info Section
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'What\'s Included',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          _buildInfoTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Credentials',
            subtitle: '${viewModel.credentialCount} credentials',
          ),

          const SizedBox(height: 12),

          _buildInfoTile(
            icon: Icons.fingerprint_rounded,
            title: 'DIDs',
            subtitle: '${viewModel.didCount} identifiers',
          ),

          const SizedBox(height: 12),

          _buildInfoTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'App preferences and configuration',
          ),

          const SizedBox(height: 32),

          // Warning Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Important',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your backup file secure. Anyone with access to your backup can restore your wallet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  BackupViewModel viewModelBuilder(BuildContext context) => BackupViewModel();

  @override
  void onViewModelReady(BackupViewModel viewModel) => viewModel.initialize();
}
