import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/notifications/push_service.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerBundledFontLicences();

  // Release builds block plain HTTP, so a release built without
  // --dart-define=API_BASE_URL=https://… would fail every request. Say so
  // plainly instead of showing "no internet" on every screen.
  if (kReleaseMode && !apiBaseUrl.startsWith('https://')) {
    runApp(const _MisconfiguredBuildApp());
    return;
  }

  // Firebase is initialised only when credentials are present, so the app still
  // runs for contributors without google-services.json installed. This must
  // never stop the UI from starting.
  final push = PushService();
  try {
    await push.initialize();
  } catch (error) {
    debugPrint('Push notifications unavailable: $error');
  }

  runApp(
    ProviderScope(
      overrides: [pushServiceProvider.overrideWithValue(push)],
      child: const BirthdayReminderApp(),
    ),
  );
}

class _MisconfiguredBuildApp extends StatelessWidget {
  const _MisconfiguredBuildApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'This build has no server address.\n\n'
                'Rebuild it with --dart-define=API_BASE_URL=https://your-worker-url.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The OFL requires the licence to ship alongside the font software, so both
/// texts are bundled and surfaced in the app's licence page.
void _registerBundledFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'DMSans': 'assets/fonts/OFL-DMSans.txt',
      'Fraunces': 'assets/fonts/OFL-Fraunces.txt',
    }.entries) {
      final licence = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], licence);
    }
  });
}
