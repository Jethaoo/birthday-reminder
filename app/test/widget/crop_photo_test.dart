import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:birthday_reminder/app/theme.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:birthday_reminder/features/photos/photo_pipeline.dart';
import 'package:birthday_reminder/features/photos/photo_providers.dart';
import 'package:birthday_reminder/features/photos/presentation/crop_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_photos.dart';

Widget _host(
  Uint8List image,
  FakePhotoCodec codec,
  void Function(Uint8List?) onResult,
) {
  return ProviderScope(
    overrides: [
      photoPipelineProvider.overrideWithValue(PhotoPipeline(codec: codec)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                onResult(await CropPhotoScreen.show(context, image));
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The editor parses on a background isolate and decodes the photo through the
/// engine's async codec, so advancing fake time is not enough: the test has to
/// let real async work run, twice, before the photo is actually on screen.
Future<void> _settleCrop(WidgetTester tester) async {
  for (var round = 0; round < 2; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('crops the photo and returns upload-ready bytes', (tester) async {
    final png = await tester.runAsync(testPng);
    final codec = FakePhotoCodec();
    Uint8List? returned;

    await tester.pumpWidget(_host(png!, codec, (bytes) => returned = bytes));
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _settleCrop(tester);

    expect(find.text('Crop photo'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);

    await tester.tap(find.text('Use photo'));
    await _settleCrop(tester);

    expect(codec.calls, hasLength(1));
    expect(codec.calls.single.correctOrientation, isFalse);
    expect(returned, isNotNull);
    expect(returned, isNotEmpty);
  });

  testWidgets('Reset recovers from a pan', (tester) async {
    final png = await tester.runAsync(testPng);
    final codec = FakePhotoCodec();

    await tester.pumpWidget(_host(png!, codec, (_) {}));
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _settleCrop(tester);

    // Nothing has moved yet, so there is nothing to reset.
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
          .onPressed,
      isNull,
    );

    await tester.drag(find.byType(Crop), const Offset(-40, -40));
    await tester.pump();

    final reset = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(reset.onPressed, isNotNull);

    reset.onPressed!();
    await tester.pump();
    await _settleCrop(tester);

    expect(find.text('Crop photo'), findsOneWidget);
  });

  testWidgets('Reset restores the opening framing, not just the crop box', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final png = await tester.runAsync(testPng);
    final codec = FakePhotoCodec();
    final preview = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoPipelineProvider.overrideWithValue(PhotoPipeline(codec: codec)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RepaintBoundary(
            key: preview,
            child: CropPhotoScreen(image: png!),
          ),
        ),
      ),
    );
    await tester.pump();
    await _settleCrop(tester);

    Future<Uint8List> capture() async {
      final boundary =
          preview.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    final before = await tester.runAsync(capture);

    await tester.drag(find.byType(Crop), const Offset(-40, -30));
    await tester.pump();
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
        .onPressed!();
    await tester.pump();
    await _settleCrop(tester);

    final after = await tester.runAsync(capture);

    // Regression: Reset used to keep the photo at fit size, so everything
    // outside the square went black instead of showing the dimmed photo.
    expect(after, equals(before));
  });

  testWidgets('backing out returns nothing', (tester) async {
    final png = await tester.runAsync(testPng);
    final codec = FakePhotoCodec();
    Uint8List? returned;

    await tester.pumpWidget(_host(png!, codec, (bytes) => returned = bytes));
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _settleCrop(tester);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, isNull);
    expect(codec.calls, isEmpty);
  });
}
