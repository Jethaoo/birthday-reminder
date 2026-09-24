import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA timezone, e.g. `Asia/Kuala_Lumpur`.
///
/// Reminder times are interpreted in this zone on the server, so the app
/// reports it on sign-in and whenever it changes.
Future<String> deviceTimezone() async {
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    if (timezone.isNotEmpty) return timezone;
  } catch (_) {
    // Falls through to a safe default when the platform channel is unavailable.
  }
  return 'UTC';
}
