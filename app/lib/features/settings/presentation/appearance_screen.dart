import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/user_settings.dart';
import '../settings_providers.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(themeModeProvider);

    Future<void> select(AppThemeMode next) async {
      await ref.read(themeModeProvider.notifier).setMode(next);
      final settings = ref.read(settingsProvider).valueOrNull;
      if (settings == null) return;
      try {
        await ref.read(settingsProvider.notifier).save(settings.copyWith(themeMode: next));
      } on ApiException {
        // The local preference still applies; the server syncs on the next change.
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Theme', style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final option in AppThemeMode.values)
                  ListTile(
                    onTap: () => select(option),
                    title: Text(switch (option) {
                      AppThemeMode.system => 'System',
                      AppThemeMode.light => 'Light',
                      AppThemeMode.dark => 'Dark',
                    }),
                    subtitle: Text(switch (option) {
                      AppThemeMode.system => 'Match your device setting',
                      AppThemeMode.light => 'Always use the light theme',
                      AppThemeMode.dark => 'Always use the dark theme',
                    }),
                    trailing: Icon(
                      mode == option ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: mode == option ? paletteOf(context).accentText : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
