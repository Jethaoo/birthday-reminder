import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/calendar_month.dart';
import '../../../shared/widgets/birthday_tile.dart';
import '../../../shared/widgets/states.dart';
import '../calendar_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  late DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  void _move(int months) {
    setState(() {
      final next = DateTime(_year, _month + months, 1);
      _year = next.year;
      _month = next.month;
    });
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _year = now.year;
      _month = now.month;
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(calendarProvider(calendarKey(_year, _month)));
    final grid = buildCalendarGrid(_year, _month);

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
          Text('Calendar', style: text.displaySmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _move(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(monthTitle(_month, _year), style: text.titleMedium),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _move(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final label in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                        Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: text.labelSmall?.copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  state.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: ErrorView(
                        title: 'Calendar unavailable',
                        message: error is ApiException ? error.message : 'Please try again.',
                        onRetry: () => ref.invalidate(calendarProvider(calendarKey(_year, _month))),
                      ),
                    ),
                    data: (month) => _Grid(
                      days: grid,
                      month: month,
                      displayedMonth: _month,
                      selected: _selected,
                      onSelect: (date) => setState(() => _selected = date),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _today,
                    style: TextButton.styleFrom(foregroundColor: palette.accentText),
                    child: const Text('Today'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: longDate(_selected)),
          state.maybeWhen(
            data: (month) {
              final day = month.dayFor(_selected);
              if (day == null || day.birthdays.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text('No birthdays on this day.', style: text.bodySmall),
                );
              }
              return Column(
                children: [
                  for (final birthday in day.birthdays) ...[
                    BirthdayTile(
                      birthday: birthday,
                      onTap: () => context.push('/birthdays/${birthday.id}'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.days,
    required this.month,
    required this.displayedMonth,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final CalendarMonth month;
  final int displayedMonth;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final today = DateTime.now();

    return Column(
      children: [
        for (var week = 0; week < 6; week += 1)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday += 1)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final date = days[week * 7 + weekday];
                      final inMonth = date.month == displayedMonth;
                      final isSelected = isSameDay(date, selected);
                      final isToday = isSameDay(date, today);
                      final hasBirthday = month.dayFor(date)?.birthdays.isNotEmpty ?? false;

                      return Semantics(
                        label:
                            '${longDate(date)}${hasBirthday ? ', has birthdays' : ''}',
                        selected: isSelected,
                        child: InkWell(
                          onTap: () => onSelect(date),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            height: 46,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? palette.primary
                                        : isToday
                                            ? palette.softPink
                                            : Colors.transparent,
                                  ),
                                  child: Text(
                                    '${date.day}',
                                    style: text.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? palette.onPrimary
                                          : inMonth
                                              ? palette.textPrimary
                                              : palette.textSecondary.withValues(alpha: 0.5),
                                      fontWeight: hasBirthday ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (hasBirthday)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
