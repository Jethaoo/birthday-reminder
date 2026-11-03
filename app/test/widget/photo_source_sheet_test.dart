import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/features/photos/presentation/photo_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Widget _host(void Function(ImageSource?) onResult) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              onResult(await showPhotoSourceSheet(context));
            },
            child: const Text('Add photo'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers the camera and the library', (tester) async {
    ImageSource? chosen;
    await tester.pumpWidget(_host((source) => chosen = source));

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(chosen, ImageSource.camera);
  });

  testWidgets('the library option reports a gallery pick', (tester) async {
    ImageSource? chosen;
    await tester.pumpWidget(_host((source) => chosen = source));

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(chosen, ImageSource.gallery);
  });

  testWidgets('dismissing reports no source', (tester) async {
    var called = false;
    ImageSource? chosen;
    await tester.pumpWidget(
      _host((source) {
        called = true;
        chosen = source;
      }),
    );

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(chosen, isNull);
  });
}
