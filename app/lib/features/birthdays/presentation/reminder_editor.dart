import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/reminder.dart';

/// Dialog used to add a reminder, shared by the form and the detail screen.
Future<Reminder?> showAddReminderDialog(
  BuildContext context, {
  List<Reminder> existing = const [],
  int initialDaysBefore = 7,
  String initialTime = '09:00',
}) async {
  var days = initialDaysBefore;
  var time = initialTime;
  final palette = paletteOf(context);

  final result = await showDialog<Reminder>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final taken = existing.map((reminder) => reminder.daysBefore).toSet();
        final available = Reminder.supportedDays.where((value) => !taken.contains(value)).toList();
        if (available.isNotEmpty && !available.contains(days)) days = available.first;

        final parts = time.split(':');
        final timeOfDay = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: int.tryParse(parts.last) ?? 0,
        );

        return AlertDialog(
          title: const Text('Add reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue:
                    available.contains(days) ? days : (available.isEmpty ? null : available.first),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'When'),
                items: [
                  for (final value in available)
                    DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 0
                            ? 'On birthday'
                            : value == 1
                                ? '1 day before'
                                : '$value days before',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => days = value ?? days),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                  if (picked != null) {
                    setState(() => time = toReminderTimeValue(picked.hour, picked.minute));
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Time'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatReminderTime(time)),
                      const Icon(Icons.schedule, size: 18),
                    ],
                  ),
                ),
              ),
              if (available.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Every reminder period is already in use.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: available.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        Reminder(
                          id: 'new-$days-$time',
                          daysBefore: days,
                          reminderTime: time,
                          enabled: true,
                        ),
                      ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );

  return result;
}
