import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme.dart';
import '../../../core/providers.dart';

String _versionLabel(PackageInfo info) {
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final package = ref.watch(packageInfoProvider);
    final version = package.maybeWhen(data: _versionLabel, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text('🎂', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Birthday Reminder',
            style: text.displaySmall?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(
            version == null ? 'Version unavailable' : 'Version $version',
            style: text.bodySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Save the birthdays that matter, get a reminder before the day and keep gift ideas in one place. '
            'Your birthdays are stored in your account so they follow you to every device you sign in on.',
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('Privacy policy'),
                  subtitle: Text('How your data is handled'),
                ),
                const Divider(height: 1),
                const ListTile(
                  title: Text('Terms of service'),
                  subtitle: Text('Rules for using the app'),
                ),
                Divider(height: 1),
                ListTile(
                  title: const Text('Open source licences'),
                  subtitle: const Text('Bundled fonts and packages'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Birthday Reminder',
                    applicationVersion: version,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reminders are delivered by push notification. Times are interpreted in your timezone, '
            'and 29 February birthdays are celebrated on 28 February in non-leap years.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
