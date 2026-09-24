import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/birthday.dart';
import '../../../shared/widgets/birthday_tile.dart';
import '../../../shared/widgets/states.dart';
import '../birthday_providers.dart';

const _filters = <({String value, String label})>[
  (value: 'all', label: 'All'),
  (value: 'today', label: 'Today'),
  (value: 'this_week', label: 'This week'),
  (value: 'this_month', label: 'This month'),
  (value: 'family', label: 'Family'),
  (value: 'friend', label: 'Friend'),
  (value: 'colleague', label: 'Colleague'),
  (value: 'other', label: 'Other'),
];

const _sorts = <({String value, String label})>[
  (value: 'upcoming', label: 'Upcoming'),
  (value: 'name', label: 'Name'),
  (value: 'recently_added', label: 'Recently added'),
];

class BirthdaysScreen extends ConsumerStatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  ConsumerState<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends ConsumerState<BirthdaysScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 320) {
        ref.read(birthdayListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(birthdayListProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(birthdayListProvider);
    final current = state.valueOrNull;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Birthdays', style: text.displaySmall),
                PopupMenuButton<String>(
                  tooltip: 'Sort birthdays',
                  initialValue: current?.sort ?? 'upcoming',
                  onSelected: (value) => ref.read(birthdayListProvider.notifier).setSort(value),
                  itemBuilder: (context) => [
                    for (final sort in _sorts)
                      PopupMenuItem(value: sort.value, child: Text(sort.label)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sort_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _sorts.firstWhere((sort) => sort.value == (current?.sort ?? 'upcoming')).label,
                          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search birthdays...',
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: palette.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.accent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = (current?.filter ?? 'all') == filter.value;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => ref.read(birthdayListProvider.notifier).setFilter(filter.value),
                  label: Text(
                    filter.label,
                    style: text.bodySmall?.copyWith(
                      color: selected ? palette.onPrimary : palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  showCheckmark: false,
                  backgroundColor: palette.surface,
                  selectedColor: palette.primary,
                  side: BorderSide(color: selected ? palette.primary : palette.border),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: const [LoadingSkeletonList(rows: 5)],
              ),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  const SizedBox(height: 60),
                  ErrorView(
                    title: 'We could not load birthdays',
                    message: error is ApiException ? error.message : 'Please try again.',
                    onRetry: () => ref.read(birthdayListProvider.notifier).refresh(),
                  ),
                ],
              ),
              data: (list) {
                if (list.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(birthdayListProvider.notifier).refresh(),
                    child: ListView(
                      controller: _scrollController,
                      children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          title: (list.search.isEmpty && list.filter == 'all')
                              ? 'No birthdays yet'
                              : 'No birthdays found',
                          message: (list.search.isEmpty && list.filter == 'all')
                              ? 'Add your first birthday and never forget an important date.'
                              : 'Try another search or filter.',
                          action: (list.search.isEmpty && list.filter == 'all')
                              ? FilledButton(
                                  onPressed: () => context.push('/birthdays/new'),
                                  child: const Text('Add birthday'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(birthdayListProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      8,
                      AppSpacing.screenPadding,
                      140,
                    ),
                    itemCount: list.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == list.items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: list.loadingMore
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    list.hasMore
                                        ? 'Scroll for more'
                                        : '${list.total} birthday${list.total == 1 ? '' : 's'}',
                                    style: text.bodySmall,
                                  ),
                          ),
                        );
                      }

                      final birthday = list.items[index];
                      return BirthdayTile(
                        birthday: birthday.toSummary(),
                        onTap: () => context.push('/birthdays/${birthday.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
