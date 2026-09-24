import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/home_summary.dart';
import '../../../shared/widgets/birthday_tile.dart';
import '../../../shared/widgets/states.dart';
import '../home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final home = ref.watch(homeProvider);
    final user = ref.watch(authControllerProvider).user;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).refresh(),
        child: home.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: const [LoadingSkeletonList(rows: 4, height: 88)],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const SizedBox(height: 80),
              ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'We could not load your birthdays.',
                onRetry: () => ref.invalidate(homeProvider),
              ),
            ],
          ),
          data: (summary) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              12,
              AppSpacing.screenPadding,
              140,
            ),
            children: [
              _Header(
                greeting: _greeting(),
                initials: user?.initials ?? '?',
                onProfileTap: () => context.go('/settings'),
              ),
              const SizedBox(height: 28),
              _TodaySection(summary: summary),
              const SizedBox(height: 28),
              _UpcomingSection(summary: summary),
              const SizedBox(height: 24),
              MonthlySummaryCard(
                monthName: summary.monthlySummary.monthName,
                total: summary.monthlySummary.total,
                upcoming: summary.monthlySummary.upcoming,
                today: summary.monthlySummary.today,
                onTap: () => context.go('/calendar'),
              ),
              if (summary.today.isEmpty && summary.upcoming.isEmpty) ...[
                const SizedBox(height: 24),
                EmptyState(
                  title: 'No birthdays yet',
                  message: 'Add your first birthday and never forget an important date.',
                  action: FilledButton(
                    onPressed: () => context.push('/birthdays/new'),
                    child: const Text('Add birthday'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Times shown in ${user?.timezone ?? 'your timezone'}',
                  style: text.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.initials, required this.onProfileTap});

  final String greeting;
  final String initials;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weekdayDate(DateTime.now()),
                style: text.bodySmall?.copyWith(color: palette.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text('$greeting 👋', style: text.displaySmall),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Open settings',
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle),
              child: Text(
                initials,
                style: text.labelLarge?.copyWith(color: palette.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final today = summary.today;
    final palette = paletteOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's birthdays",
          trailing: today.isEmpty
              ? null
              : StatusPill(label: '${today.length} today', background: palette.softPink),
        ),
        if (today.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No birthdays today', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('Enjoy the day! 🎉', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
        else ...[
          TodayBirthdayCard(
            birthday: today.first,
            onTap: () => context.push('/birthdays/${today.first.id}'),
          ),
          for (final person in today.skip(1)) ...[
            const SizedBox(height: 10),
            BirthdayTile(
              birthday: person,
              onTap: () => context.push('/birthdays/${person.id}'),
            ),
          ],
        ],
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final upcoming = summary.upcoming;

    if (upcoming.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Coming up'),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('You are all caught up! 🎉'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Coming up',
          trailing: TextButton(
            onPressed: () => context.go('/birthdays'),
            child: const Text('View all'),
          ),
        ),
        for (final person in upcoming.take(3)) ...[
          const SizedBox(height: 8),
          BirthdayTile(
            birthday: person,
            onTap: () => context.push('/birthdays/${person.id}'),
          ),
        ],
      ],
    );
  }
}
