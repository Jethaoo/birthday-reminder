import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text('🎂', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Birthday Reminder', style: text.displaySmall?.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text('Version $appVersion', style: text.bodySmall),
          const SizedBox(height: 20),
          Text(
            'Save the birthdays that matter, get a reminder before the day and keep gift ideas in one place. '
            'Your birthdays are stored in your account so they follow you to every device you sign in on.',
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: const [
                ListTile(title: Text('Privacy policy'), subtitle: Text('How your data is handled')),
                Divider(height: 1),
                ListTile(title: Text('Terms of service'), subtitle: Text('Rules for using the app')),
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
