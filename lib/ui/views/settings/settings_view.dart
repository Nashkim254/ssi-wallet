import 'package:flutter/material.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:ssi/ui/views/settings/settings_viewmodel.dart';
import 'package:stacked/stacked.dart';

class SettingsView extends StackedView<SettingsViewModel> {
  const SettingsView({super.key});

  @override
  Widget builder(
    BuildContext context,
    SettingsViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildSection(
            title: 'Profile',
            children: [
              _buildListTile(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: 'View and edit your profile',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.fingerprint_rounded,
                title: 'DIDs',
                subtitle: '${viewModel.didCount} active identifiers',
                onTap: viewModel.navigateToDidManagement,
              ),
            ],
          ),

          // Security Section
          _buildSection(
            title: 'Security',
            children: [
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric Authentication',
                subtitle: viewModel.biometricType,
                value: viewModel.biometricEnabled,
                onChanged: viewModel.toggleBiometric,
              ),
              _buildListTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change PIN',
                subtitle: 'Update your security PIN',
                onTap: viewModel.navigateToSecurity,
              ),
              _buildListTile(
                icon: Icons.security_rounded,
                title: 'Security Settings',
                subtitle: 'Advanced security options',
                onTap: viewModel.navigateToSecurity,
              ),
            ],
          ),

          // Data Section
          _buildSection(
            title: 'Data & Storage',
            children: [
              _buildListTile(
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Secure your wallet data',
                onTap: viewModel.navigateToBackup,
              ),
              _buildListTile(
                icon: Icons.storage_rounded,
                title: 'Storage',
                subtitle: '${viewModel.credentialCount} credentials stored',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.delete_outline_rounded,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: viewModel.clearCache,
                textColor: AppColors.warning,
              ),
            ],
          ),

          // Preferences Section
          _buildSection(
            title: 'Preferences',
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Receive activity alerts',
                value: viewModel.notificationsEnabled,
                onChanged: viewModel.toggleNotifications,
              ),
              _buildListTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: 'Light mode',
                onTap: () {},
              ),
            ],
          ),

          // About Section
          _buildSection(
            title: 'About',
            children: [
              _buildListTile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                subtitle: viewModel.appVersion,
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Legal information',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Get assistance',
                onTap: () {},
              ),
            ],
          ),

          // Danger Zone
          _buildSection(
            title: 'Danger Zone',
            children: [
              _buildListTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'Sign out of your wallet',
                onTap: viewModel.signOut,
                textColor: AppColors.error,
              ),
              _buildListTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Wallet',
                subtitle: 'Permanently delete all data',
                onTap: viewModel.deleteWallet,
                textColor: AppColors.error,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Footer
          Center(
            child: Column(
              children: [
                const Text(
                  'SSI Wallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Procivis One Core',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (textColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: textColor ?? AppColors.primary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: textColor ?? AppColors.grey400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  @override
  SettingsViewModel viewModelBuilder(BuildContext context) =>
      SettingsViewModel();

  @override
  void onViewModelReady(SettingsViewModel viewModel) => viewModel.initialize();
}
