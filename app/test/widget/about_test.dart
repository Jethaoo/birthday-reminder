import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/features/settings/presentation/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('shows the installed package version and build number', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Birthday Reminder',
              packageName: 'com.birthdayreminder.app',
              version: '1.3.0',
              buildNumber: '7',
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.3.0+7'), findsOneWidget);
  });
}
