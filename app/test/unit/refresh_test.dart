import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/features/birthdays/birthday_providers.dart';
import 'package:birthday_reminder/features/home/home_providers.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

/// The in-place refresh the app uses when it returns to the foreground or
/// reconnects: the point is that it never blanks what the user is reading.
void main() {
  setUp(setUpPrefs);

  ProviderContainer signedIn(FakeApi api) => ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
          authControllerProvider.overrideWith(() => FakeAuthController(testUser)),
        ],
      );

  test('revalidating the list picks up new data without emptying it', () async {
    final api = FakeApi(birthdays: [sampleBirthday(id: 'birthday-1', name: 'Sarah Tan')]);
    final container = signedIn(api);
    addTearDown(container.dispose);

    await container.read(birthdayListProvider.future);
    expect(container.read(birthdayListProvider).value?.items.single.name, 'Sarah Tan');

    final seen = <AsyncValue<BirthdayListState>>[];
    container.listen(birthdayListProvider, (_, next) => seen.add(next));

    // Added on another device while this one was in the background.
    api.birthdaysValue.add(sampleBirthday(id: 'birthday-2', name: 'Alex Lim'));
    await container.read(birthdayListProvider.notifier).revalidate();

    final names = container.read(birthdayListProvider).value?.items.map((entry) => entry.name);
    expect(names, contains('Alex Lim'));
    // Regression: every refresh used to pass through AsyncLoading, which blanked
    // the list and flashed a skeleton.
    expect(seen.any((state) => state.isLoading), isFalse);
  });

  test('revalidating the dashboard keeps a value on screen throughout', () async {
    final api = FakeApi();
    final container = signedIn(api);
    addTearDown(container.dispose);

    await container.read(homeProvider.future);

    final seen = <AsyncValue<HomeSummary>>[];
    container.listen(homeProvider, (_, next) => seen.add(next));

    await container.read(homeProvider.notifier).revalidate();

    expect(container.read(homeProvider).hasValue, isTrue);
    expect(seen.any((state) => state.isLoading), isFalse);
  });
}
