import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBanner(WidgetTester tester, {required bool online, DateTime? syncedAt}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(online)),
          lastSyncedProvider.overrideWith((ref) async => syncedAt),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: OfflineBanner()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says how old the cached data is', (tester) async {
    await pumpBanner(tester, online: false, syncedAt: DateTime(2026, 10, 15, 22, 31));
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing data from'), findsOneWidget);
  });

  testWidgets('says so when nothing has been saved yet', (tester) async {
    await pumpBanner(tester, online: false);

    expect(find.textContaining('Showing the last data this phone saved'), findsOneWidget);
  });

  testWidgets('stays out of the way while online', (tester) async {
    await pumpBanner(tester, online: true, syncedAt: DateTime(2026, 10, 15, 22, 31));

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.textContaining('No connection'), findsNothing);
  });
}
