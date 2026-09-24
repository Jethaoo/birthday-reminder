import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/features/birthdays/presentation/birthday_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('requires a name and a date', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(const BirthdayFormScreen(), api: api, auth: signedInState),
    );
    await tester.pump();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save birthday'));

    expect(find.text('Name is required.'), findsOneWidget);
    expect(api.created, isEmpty);

    // With a name supplied the form then asks for the date.
    await tester.enterText(find.byType(TextFormField).first, 'Sarah Tan');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save birthday'));

    expect(find.text('Pick the birthday date.'), findsOneWidget);
    expect(api.created, isEmpty);
  });

  testWidgets('saves a birthday with only a name and date', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(const BirthdayFormScreen(), api: api, auth: signedInState),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Sarah Tan');
    await tapVisible(tester, find.text('Select month and day'));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Set'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 January'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save birthday'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.created, hasLength(1));
    expect(api.created.single.name, 'Sarah Tan');
    expect(api.created.single.birthdayMonth, 1);
    expect(api.created.single.giftIdeas, isEmpty);
  });

  testWidgets('offers to update an existing duplicate', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi()
      ..nextError = ApiException(
        ApiErrorCode.conflict,
        'This birthday already exists.',
        details: const {'existingBirthdayId': 'birthday-9'},
      );

    await tester.pumpWidget(
      wrapWithRouter(const BirthdayFormScreen(), api: api, auth: signedInState),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Sarah Tan');
    await tapVisible(tester, find.text('Select month and day'));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Set'));
    await tester.pump(const Duration(milliseconds: 300));

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save birthday'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('This birthday already exists. Update the existing entry instead?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update existing'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Update existing'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.updated, hasLength(1));
    expect(api.updated.single.id, 'birthday-9');
  });

  testWidgets('adds gift ideas to the list', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(const BirthdayFormScreen(), api: api, auth: signedInState),
    );
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Add a gift idea'), 'Perfume');
    await tapVisible(tester, find.byTooltip('Add gift idea'));

    expect(find.widgetWithText(Chip, 'Perfume'), findsOneWidget);
  });
}
