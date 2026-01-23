import 'package:flutter/material.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:intl/intl.dart';

enum ActivityType {
  credentialReceived,
  credentialShared,
  credentialDeleted,
  didCreated,
  didDeleted,
  presentationRequest,
}

class ActivityViewModel extends BaseViewModel {
  final _procivisService = locator<ProcivisService>();
  final _bottomSheetService = locator<BottomSheetService>();

  List<ActivityItem> _activities = [];

  List<ActivityItem> get activities => _activities;

  List<ActivityGroup> get groupedActivities {
    final Map<String, List<ActivityItem>> grouped = {};

    for (final activity in _activities) {
      final dateKey = _formatDateKey(activity.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(activity);
    }

    return grouped.entries.map((entry) {
      return ActivityGroup(
        date: entry.key,
        activities: entry.value,
      );
    }).toList();
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      // Load activity from Procivis service
      final history = await _procivisService.getInteractionHistory();

      // Convert to ActivityItem objects
      _activities = history.map((item) {
        return _parseActivityItem(item);
      }).toList();

      // Sort by timestamp (newest first)
      _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Add some mock activities for demonstration
      _addMockActivities();
    } catch (e) {
      print('Failed to load activity: $e');
      _addMockActivities();
    } finally {
      setBusy(false);
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  Future<void> showFilterOptions() async {
    // Show filter options - using notice sheet as a placeholder
    await _bottomSheetService.showBottomSheet(
      title: 'Filter Activity',
      description: 'Choose activity types to display:\n\n• All Activity\n• Credentials Only\n• Presentations Only\n• DID Operations',
    );
  }

  ActivityItem _parseActivityItem(Map<String, dynamic> item) {
    final type = item['type'] as String?;
    final timestamp = DateTime.parse(item['timestamp'] as String);

    switch (type) {
      case 'credential_received':
        return ActivityItem(
          type: ActivityType.credentialReceived,
          title: 'Credential Received',
          description: item['credentialName'] ?? 'New credential',
          timestamp: timestamp,
          icon: Icons.add_card_rounded,
          color: AppColors.success,
        );
      case 'credential_shared':
        return ActivityItem(
          type: ActivityType.credentialShared,
          title: 'Credential Shared',
          description: item['verifierName'] ?? 'Shared with verifier',
          timestamp: timestamp,
          icon: Icons.share_rounded,
          color: AppColors.primary,
        );
      default:
        return ActivityItem(
          type: ActivityType.credentialReceived,
          title: 'Activity',
          description: 'Unknown activity',
          timestamp: timestamp,
          icon: Icons.circle_rounded,
          color: AppColors.grey400,
        );
    }
  }

  void _addMockActivities() {
    final now = DateTime.now();

    _activities = [
      ActivityItem(
        type: ActivityType.credentialReceived,
        title: 'Credential Received',
        description: 'University Degree from MIT',
        timestamp: now.subtract(const Duration(hours: 2)),
        icon: Icons.add_card_rounded,
        color: AppColors.success,
      ),
      ActivityItem(
        type: ActivityType.credentialShared,
        title: 'Credential Shared',
        description: 'Shared Driver\'s License with DMV Portal',
        timestamp: now.subtract(const Duration(days: 1)),
        icon: Icons.share_rounded,
        color: AppColors.primary,
      ),
      ActivityItem(
        type: ActivityType.didCreated,
        title: 'DID Created',
        description: 'Created new did:key identifier',
        timestamp: now.subtract(const Duration(days: 2)),
        icon: Icons.fingerprint_rounded,
        color: AppColors.secondary,
      ),
      ActivityItem(
        type: ActivityType.presentationRequest,
        title: 'Presentation Request',
        description: 'Request from Employer Portal (Declined)',
        timestamp: now.subtract(const Duration(days: 3)),
        icon: Icons.verified_user_rounded,
        color: AppColors.warning,
      ),
      ActivityItem(
        type: ActivityType.credentialReceived,
        title: 'Credential Received',
        description: 'Driver\'s License from DMV',
        timestamp: now.subtract(const Duration(days: 5)),
        icon: Icons.add_card_rounded,
        color: AppColors.success,
      ),
    ];
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateOnly).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMMM d').format(date);
    }
  }
}

class ActivityItem {
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  ActivityItem({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class ActivityGroup {
  final String date;
  final List<ActivityItem> activities;

  ActivityGroup({
    required this.date,
    required this.activities,
  });
}
