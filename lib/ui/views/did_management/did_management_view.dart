import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:ssi/ui/widgets/empty_state.dart';
import 'package:stacked/stacked.dart';
import 'package:intl/intl.dart';

import 'did_management_viewmodel.dart';

class DidManagementView extends StackedView<DidManagementViewModel> {
  const DidManagementView({super.key});

  @override
  Widget builder(
    BuildContext context,
    DidManagementViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decentralized Identifiers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: viewModel.showDidInfo,
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : viewModel.dids.isEmpty
              ? EmptyState(
                  icon: Icons.fingerprint_rounded,
                  title: 'No DIDs Yet',
                  message:
                      'Create your first decentralized identifier to get started',
                  actionLabel: 'Create DID',
                  onActionPressed: viewModel.showCreateDidDialog,
                )
              : RefreshIndicator(
                  onRefresh: viewModel.refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Default DID Card
                      if (viewModel.defaultDid != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Default Identity',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            _buildDidCard(
                              viewModel.defaultDid!,
                              isDefault: true,
                              onTap: () => viewModel
                                  .showDidDetails(viewModel.defaultDid!),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Other DIDs
                      if (viewModel.otherDids.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Other Identifiers',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            ...viewModel.otherDids.asMap().entries.map((entry) {
                              final index = entry.key;
                              final did = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildDidCard(
                                  did,
                                  isDefault: false,
                                  onTap: () => viewModel.showDidDetails(did),
                                )
                                    .animate()
                                    .fadeIn(delay: (100 * index).ms)
                                    .slideX(begin: -0.2, end: 0),
                              );
                            }).toList(),
                          ],
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.showCreateDidDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create DID'),
      ).animate().scale(delay: 300.ms),
    );
  }

  Widget _buildDidCard(did,
      {required bool isDefault, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDefault
              ? AppColors.primaryGradient
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDefault
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Method badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    did.method.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // DID String
            Row(
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 20,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _shortenDid(did.didString),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Key type and created date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.key_rounded,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      did.keyType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, y').format(did.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortenDid(String did) {
    if (did.length <= 40) return did;
    return '${did.substring(0, 20)}...${did.substring(did.length - 16)}';
  }

  @override
  DidManagementViewModel viewModelBuilder(BuildContext context) =>
      DidManagementViewModel();

  @override
  void onViewModelReady(DidManagementViewModel viewModel) =>
      viewModel.initialize();
}
