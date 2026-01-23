import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:ssi/ui/widgets/empty_state.dart';
import 'package:stacked/stacked.dart';
import 'package:intl/intl.dart';

import 'activity_viewmodel.dart';

class ActivityView extends StackedView<ActivityViewModel> {
  const ActivityView({super.key});

  @override
  Widget builder(
    BuildContext context,
    ActivityViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: viewModel.showFilterOptions,
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : viewModel.activities.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No Activity Yet',
                  message: 'Your credential activity will appear here',
                )
              : RefreshIndicator(
                  onRefresh: viewModel.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: viewModel.groupedActivities.length,
                    itemBuilder: (context, index) {
                      final group = viewModel.groupedActivities[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              top: index == 0 ? 0 : 24,
                              bottom: 12,
                            ),
                            child: Text(
                              group.date,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Activities for this date
                          ...group.activities.map((activity) {
                            return _buildActivityItem(activity)
                                .animate()
                                .fadeIn()
                                .slideX(begin: -0.2, end: 0);
                          }).toList(),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.icon,
              color: activity.color,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(activity.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),

          // Chevron
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.grey400,
            size: 20,
          ),
        ],
      ),
    );
  }

  @override
  ActivityViewModel viewModelBuilder(BuildContext context) =>
      ActivityViewModel();

  @override
  void onViewModelReady(ActivityViewModel viewModel) => viewModel.initialize();
}
