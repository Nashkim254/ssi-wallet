import 'package:flutter/material.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';

import 'security_viewmodel.dart';

class SecurityView extends StackedView<SecurityViewModel> {
  const SecurityView({super.key});

  @override
  Widget builder(
    BuildContext context,
    SecurityViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Biometric Section
          _buildCard(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Authentication',
            subtitle: viewModel.biometricEnabled
                ? 'Enabled (${viewModel.biometricType})'
                : 'Disabled',
            trailing: Switch(
              value: viewModel.biometricEnabled,
              onChanged: viewModel.toggleBiometric,
            ),
          ),

          const SizedBox(height: 16),

          // PIN Section
          _buildCard(
            icon: Icons.pin_rounded,
            title: 'Security PIN',
            subtitle: viewModel.hasPinSet
                ? 'Change your security PIN'
                : 'Set up a security PIN',
            onTap:
                viewModel.hasPinSet ? viewModel.changePin : viewModel.setupPin,
          ),

          const SizedBox(height: 16),

          // Auto-lock
          _buildCard(
            icon: Icons.lock_clock_rounded,
            title: 'Auto-Lock',
            subtitle: 'Lock app after ${viewModel.autoLockMinutes} minutes',
            onTap: viewModel.changeAutoLockDuration,
          ),

          const SizedBox(height: 32),

          // Advanced Options Header
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Advanced Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Screenshot Protection
          _buildCard(
            icon: Icons.screenshot_rounded,
            title: 'Screenshot Protection',
            subtitle: 'Prevent screenshots in the app',
            trailing: Switch(
              value: viewModel.screenshotProtectionEnabled,
              onChanged: viewModel.toggleScreenshotProtection,
            ),
          ),

          const SizedBox(height: 16),

          // Screen Recording Detection
          _buildCard(
            icon: Icons.videocam_rounded,
            title: 'Screen Recording Alert',
            subtitle: 'Alert when screen recording is detected',
            trailing: Switch(
              value: viewModel.screenRecordingAlertEnabled,
              onChanged: viewModel.toggleScreenRecordingAlert,
            ),
          ),

          const SizedBox(height: 16),

          // Require Auth for Sensitive Actions
          _buildCard(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Require Authentication',
            subtitle: 'Require auth for sharing credentials',
            trailing: Switch(
              value: viewModel.requireAuthForSharing,
              onChanged: viewModel.toggleRequireAuthForSharing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.grey400,
              ),
          ],
        ),
      ),
    );
  }

  @override
  SecurityViewModel viewModelBuilder(BuildContext context) =>
      SecurityViewModel();

  @override
  void onViewModelReady(SecurityViewModel viewModel) => viewModel.initialize();
}
