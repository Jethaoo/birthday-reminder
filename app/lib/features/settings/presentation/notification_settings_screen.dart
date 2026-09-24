import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/birthday_reminder_api.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/models/user_settings.dart';
import '../settings_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);

    Future<void> apply(UserSettings next) async {
      try {
        await ref.read(settingsProvider.notifier).save(next);
      } on ApiException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Preferences may fail to load when the backend is unreachable. That
          // must not hide the delivery test below: verifying connectivity is
          // precisely when it is needed.
          settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(Icons.cloud_off_rounded, color: palette.error),
                title: const Text('Could not load your preferences'),
                subtitle: Text(
                  error is ApiException ? error.message : 'Check your connection and try again.',
                ),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(settingsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (current) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Default reminder', style: text.titleMedium),
                const SizedBox(height: 6),
                Text('Used when you enable reminders on a new birthday.', style: text.bodySmall),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: current.defaultDaysBefore,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'When'),
                  items: [
                    for (final days in Reminder.supportedDays)
                      DropdownMenuItem(
                        value: days,
                        child: Text(
                          days == 0
                              ? 'On birthday'
                              : days == 1
                                  ? '1 day before'
                                  : '$days days before',
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      value == null ? null : apply(current.copyWith(defaultDaysBefore: value)),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final parts = current.defaultReminderTime.split(':');
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.tryParse(parts.first) ?? 9,
                        minute: int.tryParse(parts.last) ?? 0,
                      ),
                    );
                    if (picked == null) return;
                    await apply(
                      current.copyWith(
                        defaultReminderTime: toReminderTimeValue(picked.hour, picked.minute),
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Time'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatReminderTime(current.defaultReminderTime)),
                        const Icon(Icons.schedule, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text('Delivery', style: text.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Birthday reminders'),
                        value: current.remindersEnabled,
                        onChanged: (value) => apply(current.copyWith(remindersEnabled: value)),
                      ),
                      SwitchListTile(
                        title: const Text('Notification sound'),
                        subtitle: const Text('Reminders still arrive, just silently'),
                        value: current.soundEnabled,
                        onChanged: (value) => apply(current.copyWith(soundEnabled: value)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Test delivery', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Sends a push to the devices signed in to this account, so you can confirm notifications arrive. '
            'While the app is open the message appears as a banner here; leave the app to see a tray notification.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final result = await ref.read(apiProvider).sendTestNotification();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_testResultMessage(result))),
                );
              } on ApiException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Send a test notification'),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in on this device first: the push is delivered to the accounts registered here. '
            'Test notifications are only available outside production.',
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Reports what the server actually did, so "sent" is never assumed.
  String _testResultMessage(TestNotificationResult result) {
    if (result.simulated) {
      return 'Delivery simulated: the server has no FCM credentials configured.';
    }
    if (result.hasNoDevices) {
      return 'No devices registered yet. Sign in on a device before testing.';
    }
    if (result.sent > 0) {
      return 'Sent to ${result.sent} device${result.sent == 1 ? '' : 's'}. '
          'Leave the app to see it in the notification shade.';
    }
    return 'FCM rejected the message for ${result.failed} '
        'device${result.failed == 1 ? '' : 's'}.';
  }
}
