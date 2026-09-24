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
