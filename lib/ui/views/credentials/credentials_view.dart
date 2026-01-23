import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:ssi/ui/views/credentials/credentials_viewmodel.dart';
import 'package:ssi/ui/widgets/credential_card.dart';
import 'package:ssi/ui/widgets/empty_state.dart';
import 'package:stacked/stacked.dart';

class CredentialsView extends StackedView<CredentialsViewModel> {
  const CredentialsView({super.key});

  @override
  Widget builder(
    BuildContext context,
    CredentialsViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('My Credentials'),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(
              viewModel.hasActiveFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: viewModel.hasActiveFilters
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
            onPressed: viewModel.showFilterSheet,
          ),
          // Sort button
          PopupMenuButton<CredentialSortOption>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: viewModel.setSortOption,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: CredentialSortOption.dateNewest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: CredentialSortOption.dateOldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: CredentialSortOption.nameAZ,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem(
                value: CredentialSortOption.nameZA,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem(
                value: CredentialSortOption.issuer,
                child: Text('Issuer'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: viewModel.searchController,
              decoration: InputDecoration(
                hintText: 'Search credentials...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: viewModel.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: viewModel.clearSearch,
                      )
                    : null,
              ),
              onChanged: viewModel.onSearchChanged,
            ),
          ).animate().fadeIn().slideY(begin: -0.2, end: 0),

          // Active filters chips
          if (viewModel.hasActiveFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (viewModel.showExpiredOnly)
                    _buildFilterChip(
                      label: 'Expired',
                      onDeleted: () => viewModel.toggleExpiredFilter(),
                    ),
                  if (viewModel.showValidOnly)
                    _buildFilterChip(
                      label: 'Valid Only',
                      onDeleted: () => viewModel.toggleValidFilter(),
                    ),
                  if (viewModel.selectedFormat != null)
                    _buildFilterChip(
                      label: viewModel.selectedFormat!,
                      onDeleted: () => viewModel.clearFormatFilter(),
                    ),
                  TextButton.icon(
                    onPressed: viewModel.clearAllFilters,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Credentials count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${viewModel.filteredCredentials.length} ${viewModel.filteredCredentials.length == 1 ? 'credential' : 'credentials'}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Credentials list
          Expanded(
            child: viewModel.isBusy
                ? const Center(child: CircularProgressIndicator())
                : viewModel.filteredCredentials.isEmpty
                    ? EmptyState(
                        icon: viewModel.searchQuery.isNotEmpty ||
                                viewModel.hasActiveFilters
                            ? Icons.search_off_rounded
                            : Icons.account_balance_wallet_outlined,
                        title: viewModel.searchQuery.isNotEmpty ||
                                viewModel.hasActiveFilters
                            ? 'No Credentials Found'
                            : 'No Credentials Yet',
                        message: viewModel.searchQuery.isNotEmpty ||
                                viewModel.hasActiveFilters
                            ? 'Try adjusting your search or filters'
                            : 'Scan a QR code to receive your first credential',
                        actionLabel: viewModel.searchQuery.isEmpty &&
                                !viewModel.hasActiveFilters
                            ? 'Scan QR Code'
                            : null,
                        onActionPressed: viewModel.searchQuery.isEmpty &&
                                !viewModel.hasActiveFilters
                            ? viewModel.navigateToScan
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: viewModel.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: viewModel.filteredCredentials.length,
                          itemBuilder: (context, index) {
                            final credential =
                                viewModel.filteredCredentials[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CredentialCard(
                                credential: credential,
                                onTap: () => viewModel
                                    .navigateToCredentialDetail(credential.id),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: (50 * index).ms)
                                .slideX(begin: -0.2, end: 0);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.navigateToScan,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Add Credential'),
      ).animate().scale(delay: 300.ms),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onDeleted,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  CredentialsViewModel viewModelBuilder(BuildContext context) =>
      CredentialsViewModel();

  @override
  void onViewModelReady(CredentialsViewModel viewModel) =>
      viewModel.initialize();
}
