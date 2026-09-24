import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/push_service.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
