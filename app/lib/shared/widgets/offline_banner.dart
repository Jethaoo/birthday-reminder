import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';

/// Shown whenever the device has no connection. Mutations stay blocked so a
/// failed edit is never silently lost.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final offline = connectivity.maybeWhen(data: (online) => !online, orElse: () => false);
    if (!offline) return const SizedBox.shrink();

    final palette = paletteOf(context);
    return Container(
      width: double.infinity,
      color: palette.softPink,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: palette.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline. Changes are disabled until you reconnect.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.accentText),
            ),
          ),
        ],
      ),
    );
  }
}

/// True when the app should block writes.
bool isOffline(WidgetRef ref) {
  return ref.watch(connectivityProvider).maybeWhen(data: (online) => !online, orElse: () => false);
}
