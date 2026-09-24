import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/user_settings.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/states.dart';
import '../settings_providers.dart';

String _defaultReminderLabel(int daysBefore) {
  if (daysBefore == 0) return 'On birthday';
  if (daysBefore == 1) return '1 day before';
  return '$daysBefore days before';
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmLogout(context);
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;
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

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          12,
          AppSpacing.screenPadding,
          140,
        ),
        children: [
          Text('Settings', style: text.displaySmall),
          const SizedBox(height: 20),
          Text('ACCOUNT', style: text.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(user?.name ?? 'Your account', style: text.titleSmall),
              subtitle: Text(user?.email ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/account'),
            ),
          ),
          const SizedBox(height: 20),
          Text('NOTIFICATIONS', style: text.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: settings.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingSkeletonList(rows: 2, height: 44),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error is ApiException ? error.message : 'Could not load preferences.',
                  style: text.bodySmall?.copyWith(color: palette.error),
                ),
              ),
              data: (current) => Column(
                children: [
                  SwitchListTile(
                    title: const Text('Birthday reminders'),
                    subtitle: const Text('Advance reminders you configured'),
                    value: current.remindersEnabled,
                    onChanged: (value) => apply(current.copyWith(remindersEnabled: value)),
                  ),
                  SwitchListTile(
                    title: const Text("Today's birthdays"),
                    value: current.todayEnabled,
                    onChanged: (value) => apply(current.copyWith(todayEnabled: value)),
                  ),
                  SwitchListTile(
                    title: const Text('Tomorrow reminders'),
                    value: current.tomorrowEnabled,
                    onChanged: (value) => apply(current.copyWith(tomorrowEnabled: value)),
                  ),
                  SwitchListTile(
                    title: const Text('Notification sound'),
                    value: current.soundEnabled,
                    onChanged: (value) => apply(current.copyWith(soundEnabled: value)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('REMINDERS & NOTIFICATIONS', style: text.labelSmall),
          const SizedBox(height: 8),
          Card(
            // Always visible: this is the only route to the reminder and test
            // notification screen, so it must not disappear when the settings
            // request fails (which is exactly when you need it).
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text('Reminder & notification settings', style: text.titleSmall),
              subtitle: Text(
                settings.maybeWhen(
                  data: (current) =>
                      'Default: ${_defaultReminderLabel(current.defaultDaysBefore)} '
                      'at ${formatReminderTime(current.defaultReminderTime)}',
                  orElse: () => 'Default timing, sound and test notification',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: 20),
          Text('APPEARANCE', style: text.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Theme'),
              subtitle: Text(
                switch (ref.watch(themeModeProvider)) {
                  AppThemeMode.light => 'Light',
                  AppThemeMode.dark => 'Dark',
                  AppThemeMode.system => 'System',
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/appearance'),
            ),
          ),
          const SizedBox(height: 20),
          Text('ABOUT', style: text.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('About Birthday Reminder'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/about'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _logout(context, ref),
            child: const Text('Log out'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.push('/settings/account'),
            style: TextButton.styleFrom(foregroundColor: palette.error),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
