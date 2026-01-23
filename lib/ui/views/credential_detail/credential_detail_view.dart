import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';
import 'package:intl/intl.dart';

import 'credential_detail_viewmodel.dart';

class CredentialDetailView extends StackedView<CredentialDetailViewModel> {
  final String credentialId;

  const CredentialDetailView({
    super.key,
    required this.credentialId,
  });

  @override
  Widget builder(
    BuildContext context,
    CredentialDetailViewModel viewModel,
    Widget? child,
  ) {
    if (viewModel.isBusy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.credential == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credential')),
        body: const Center(
          child: Text('Credential not found'),
        ),
      );
    }

    final credential = viewModel.credential!;
    final backgroundColor = viewModel.cardBackgroundColor;
    final textColor = viewModel.cardTextColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Credential Card Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: backgroundColor,
            iconTheme: IconThemeData(color: textColor),
            actions: [
              // Share button
              IconButton(
                icon: Icon(Icons.share_rounded, color: textColor),
                onPressed: viewModel.shareCredential,
              ),
              // More options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: textColor),
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      viewModel.refreshStatus();
                      break;
                    case 'export':
                      viewModel.exportCredential();
                      break;
                    case 'delete':
                      viewModel.deleteCredential();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded),
                        SizedBox(width: 12),
                        Text('Refresh Status'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded),
                        SizedBox(width: 12),
                        Text('Export'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor,
                      backgroundColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Format badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            viewModel.formatLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Credential name
                        Text(
                          credential.name,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Issuer
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 16,
                              color: textColor.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Issued by ${credential.issuerName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Status badge
                        _buildStatusBadge(credential, textColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Quick actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.qr_code_rounded,
                            label: 'Show QR',
                            onTap: viewModel.showQRCode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.verified_user_rounded,
                            label: 'Verify',
                            onTap: viewModel.verifyCredential,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 32),

                  // Credential Information
                  _buildSection(
                    title: 'Credential Information',
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Issued Date',
                        value: DateFormat('MMMM d, y')
                            .format(credential.issuedDate),
                      ),
                      if (credential.expiryDate != null)
                        _buildInfoRow(
                          icon: Icons.event_rounded,
                          label: 'Expiry Date',
                          value: DateFormat('MMMM d, y')
                              .format(credential.expiryDate!),
                          valueColor: credential.isExpired
                              ? AppColors.error
                              : credential.isExpiringSoon
                                  ? AppColors.warning
                                  : null,
                        ),
                      _buildInfoRow(
                        icon: Icons.category_rounded,
                        label: 'Type',
                        value: credential.type,
                      ),
                      _buildInfoRow(
                        icon: Icons.document_scanner_rounded,
                        label: 'Format',
                        value: viewModel.formatLabel,
                      ),
                      if (credential.proofType != null)
                        _buildInfoRow(
                          icon: Icons.security_rounded,
                          label: 'Proof Type',
                          value: credential.proofType!,
                        ),
                    ],
                  ),

                  // Issuer Information
                  _buildSection(
                    title: 'Issuer Information',
                    children: [
                      _buildInfoRow(
                        icon: Icons.business_rounded,
                        label: 'Name',
                        value: credential.issuerName,
                      ),
                      if (credential.issuerDid != null)
                        _buildInfoRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'DID',
                          value: viewModel.shortDid(credential.issuerDid!),
                          onTap: () => viewModel.copyToClipboard(
                            credential.issuerDid!,
                            'Issuer DID',
                          ),
                          trailing: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),

                  // Holder Information
                  if (credential.holderDid != null)
                    _buildSection(
                      title: 'Holder Information',
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_rounded,
                          label: 'DID',
                          value: viewModel.shortDid(credential.holderDid!),
                          onTap: () => viewModel.copyToClipboard(
                            credential.holderDid!,
                            'Holder DID',
                          ),
                          trailing: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                  // Claims/Attributes
                  if (credential.claims.isNotEmpty)
                    _buildSection(
                      title: 'Claims',
                      children: credential.claims.entries.map((entry) {
                        return _buildClaimRow(
                          label: _formatClaimKey(entry.key),
                          value: entry.value.toString(),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(credential, Color textColor) {
    if (credential.state == 'valid' &&
        !credential.isExpired &&
        !credential.isExpiringSoon) {
      return Row(
        children: [
          Icon(
            Icons.verified_rounded,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 6),
          Text(
            'Valid',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      );
    }

    IconData icon;
    String label;
    Color badgeColor;

    if (credential.isExpired) {
      icon = Icons.error_rounded;
      label = 'Expired';
      badgeColor = AppColors.error;
    } else if (credential.isExpiringSoon) {
      icon = Icons.warning_rounded;
      label = 'Expiring Soon';
      badgeColor = AppColors.warning;
    } else {
      icon = Icons.block_rounded;
      label = credential.statusText;
      badgeColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
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
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildClaimRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatClaimKey(String key) {
    // Convert camelCase or snake_case to Title Case
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  CredentialDetailViewModel viewModelBuilder(BuildContext context) =>
      CredentialDetailViewModel(credentialId: credentialId);

  @override
  void onViewModelReady(CredentialDetailViewModel viewModel) =>
      viewModel.initialize();
}
