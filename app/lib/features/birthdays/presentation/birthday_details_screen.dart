import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/birthday.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/states.dart';
import '../birthday_providers.dart';
import 'reminder_editor.dart';

class BirthdayDetailsScreen extends ConsumerWidget {
  const BirthdayDetailsScreen({super.key, required this.birthdayId});

  final String birthdayId;

  Future<void> _addReminder(BuildContext context, WidgetRef ref, Birthday birthday) async {
    final reminder = await showAddReminderDialog(context, existing: birthday.reminders);
    if (reminder == null) return;
    try {
      await ref.read(birthdayActionsProvider).addReminder(birthday.id, reminder);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Birthday birthday) async {
    final confirmed = await confirmDeleteBirthday(context, birthday.name);
    if (!confirmed) return;

    try {
      await ref.read(birthdayActionsProvider).delete(birthday.id);
      if (context.mounted) context.go('/birthdays');
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// Back must always land somewhere. A notification can open this screen with
  /// nothing beneath it, and popping the last route closes the app.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/birthdays');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final detail = ref.watch(birthdayDetailProvider(birthdayId));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => _leave(context)),
        actions: [
          detail.maybeWhen(
            data: (birthday) => IconButton(
              tooltip: 'Edit birthday',
              onPressed: () => context.push('/birthdays/${birthday.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: LoadingSkeletonList(rows: 4, height: 64),
        ),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'We could not load this birthday.',
          onRetry: () => ref.invalidate(birthdayDetailProvider(birthdayId)),
        ),
        data: (birthday) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            40,
          ),
          children: [
            Center(
              child: Column(
                children: [
                  PersonAvatar(
                    initials: birthday.initials,
                    colorSeed: birthday.colorSeed,
                    size: 88,
                    photoUrl: birthday.photoUrl,
                  ),
                  const SizedBox(height: 14),
                  Text(birthday.name, style: text.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      longDate(DateTime(2000, birthday.birthdayMonth, birthday.birthdayDay)),
                      ?birthday.relationship,
                    ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  StatusPill(
                    label: birthday.daysUntil == 0
                        ? '🎂 Today'
                        : '🎂 ${countdownLabel(birthday.daysUntil)} left',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Card(
              title: 'Birthday',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    longDate(DateTime(2000, birthday.birthdayMonth, birthday.birthdayDay)),
                    style: text.titleSmall,
                  ),
                  if (birthday.birthYear != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      birthday.turningAge == null
                          ? 'Born ${birthday.birthYear}'
                          : 'Turning ${birthday.turningAge} on ${longDate(birthday.nextOccurrence)}',
                      style: text.bodySmall,
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text('Next on ${longDate(birthday.nextOccurrence)}', style: text.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Reminders',
              trailing: TextButton(
                onPressed: () => _addReminder(context, ref, birthday),
                child: const Text('Add'),
              ),
              child: birthday.reminders.isEmpty
                  ? Text('No reminders yet.', style: text.bodySmall)
                  : Column(
                      children: [
                        for (final reminder in birthday.reminders)
                          _ReminderRow(birthday: birthday, reminder: reminder),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Gift ideas',
              child: birthday.giftIdeas.isEmpty
                  ? Text('No gift ideas yet.', style: text.bodySmall)
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final idea in birthday.giftIdeas) Chip(label: Text(idea)),
                      ],
                    ),
            ),
            if ((birthday.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _Card(
                title: 'Notes',
                child: Text(birthday.notes!, style: text.bodyMedium),
              ),
            ],
            if ((birthday.phone ?? '').isNotEmpty || (birthday.email ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _Card(
                title: 'Contact',
                child: Column(
                  children: [
                    if ((birthday.phone ?? '').isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined),
                        title: Text(birthday.phone!),
                        trailing: const Icon(Icons.copy_rounded, size: 18),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: birthday.phone!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Phone number copied')),
                            );
                          }
                        },
                      ),
                    if ((birthday.email ?? '').isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline),
                        title: Text(birthday.email!),
                        trailing: const Icon(Icons.copy_rounded, size: 18),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: birthday.email!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email copied')),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => context.push('/birthdays/${birthday.id}/edit'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit birthday'),
            ),
            const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _delete(context, ref, birthday),
                style: TextButton.styleFrom(foregroundColor: palette.error),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete birthday'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title.toUpperCase(), style: text.labelSmall),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.birthday, required this.reminder});

  final Birthday birthday;
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final actions = ref.read(birthdayActionsProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reminder.label, style: Theme.of(context).textTheme.titleSmall),
              Text(formatReminderTime(reminder.reminderTime), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: reminder.enabled,
          onChanged: (value) async {
            try {
              await actions.updateReminder(birthday.id, reminder.copyWith(enabled: value));
            } on ApiException catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
              }
            }
          },
        ),
        IconButton(
          tooltip: 'Delete reminder',
          onPressed: () async {
            try {
              await actions.deleteReminder(birthday.id, reminder.id);
            } on ApiException catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
              }
            }
          },
          icon: Icon(Icons.delete_outline, color: palette.error),
        ),
      ],
    );
  }
}
