import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/birthday.dart';
import 'person_avatar.dart';

/// Compact row used by the Birthdays list and Home "coming up" section.
class BirthdayTile extends StatelessWidget {
  const BirthdayTile({super.key, required this.birthday, this.onTap});

  final BirthdaySummary birthday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PersonAvatar(
                initials: birthday.initials,
                colorSeed: birthday.colorSeed,
                photoUrl: birthday.photoUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(birthday.name, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      [
                        longDate(birthday.nextOccurrence),
                        if (birthday.relationship != null) birthday.relationship!,
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                countdownLabel(birthday.daysUntil),
                style: text.labelLarge?.copyWith(color: palette.accentText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hero card on Home for someone whose birthday is today.
class TodayBirthdayCard extends StatelessWidget {
  const TodayBirthdayCard({super.key, required this.birthday, this.onTap, this.onAction});

  final BirthdaySummary birthday;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final onCard = palette.heroCardText;

    return Material(
      color: palette.heroCard,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PersonAvatar(
                    initials: birthday.initials,
                    colorSeed: birthday.colorSeed,
                    photoUrl: birthday.photoUrl,
                  ),
                  if (birthday.turningAge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: onCard.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Turning ${birthday.turningAge}',
                        style: text.bodySmall?.copyWith(color: onCard, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                birthday.name,
                style: text.headlineSmall?.copyWith(color: onCard, fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Their birthday is today',
                style: text.bodyMedium?.copyWith(color: onCard.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction ?? onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('View details →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded summary panel used for the monthly overview on Home.
class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({
    super.key,
    required this.monthName,
    required this.total,
    required this.upcoming,
    required this.today,
    this.onTap,
  });

  final String monthName;
  final int total;
  final int upcoming;
  final int today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.softGreen,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthName.toUpperCase(),
                style: text.labelSmall?.copyWith(color: palette.textPrimary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 6),
              Text('A month to celebrate', style: text.headlineSmall),
              const SizedBox(height: 16),
              Divider(color: palette.border),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Metric(value: '$total', label: 'birthdays', palette: palette),
                  _Metric(value: '$upcoming', label: 'upcoming', palette: palette, bordered: true),
                  _Metric(value: '$today', label: 'today', palette: palette, bordered: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.palette,
    this.bordered = false,
  });

  final String value;
  final String label;
  final AppPalette palette;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        decoration: bordered
            ? BoxDecoration(border: Border(left: BorderSide(color: palette.border)))
            : null,
        child: Column(
          children: [
            Text(value, style: text.titleMedium?.copyWith(fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
