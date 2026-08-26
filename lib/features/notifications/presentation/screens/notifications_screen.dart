import 'package:flutter/material.dart';
import '../../../../core/theme/tokens.dart';

/// Explains what the app notifies about. Read-only for now: notification
/// scheduling is derived from each list's date and frequency, so there is no
/// per-notification setting to toggle without inventing one.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Shopping day reminder'),
              subtitle: Text(
                'Sent on the morning a list is scheduled.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Missed date notice'),
              subtitle: Text(
                'Sent when a scheduled date passes with items still unchecked.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Reminders are scheduled on this device. Turn them off in your '
            'system notification settings for Grocerio.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
