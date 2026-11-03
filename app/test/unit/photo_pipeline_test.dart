import 'package:birthday_reminder/features/photos/photo_pipeline.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_photos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sampleSizeFor', () {
    test('leaves ordinary photos at full resolution', () {
      expect(sampleSizeFor(1024), 1);
      expect(sampleSizeFor(2048), 1);
    });

    test('subsamples by powers of two until the longest edge fits', () {
      expect(sampleSizeFor(2049), 2);
      expect(sampleSizeFor(4000), 2);
      expect(sampleSizeFor(4096), 2);
      expect(sampleSizeFor(8000), 4);
      expect(sampleSizeFor(12000), 8);
    });

    test('stops at 8 so a panorama is not decoded in unusable detail', () {
      expect(sampleSizeFor(48000), 8);
    });
  });

  group('PhotoPipeline', () {
    test('uprights and shrinks the source before the editor sees it', () async {
      final codec = FakePhotoCodec();
      final pipeline = PhotoPipeline(codec: codec);
      final source = await testPng(width: 300, height: 200);

      await pipeline.shrinkForEditing(source);

      final call = codec.calls.single;
      expect(call.minWidth, avatarEdge);
      expect(call.minHeight, avatarEdge);
      expect(call.quality, 92);
      expect(call.sampleSize, 1);
      // Without this a sideways phone photo reaches the editor rotated, because
      // the EXIF tag is dropped at the end of the pipeline.
      expect(call.correctOrientation, isTrue);
    });

    test(
      'subsamples a source too large to decode, and still unknown bytes',
      () async {
        final codec = FakePhotoCodec();
        final pipeline = PhotoPipeline(codec: codec);

        // The engine cannot describe these bytes, so the pipeline falls back to
        // the conservative sample size rather than decoding at full resolution.
        await pipeline.shrinkForEditing(Uint8List.fromList([1, 2, 3, 4]));

        expect(codec.calls.single.sampleSize, 2);
      },
    );

    test(
      'encodes the crop at upload quality without rotating it again',
      () async {
        final codec = FakePhotoCodec();
        final pipeline = PhotoPipeline(codec: codec);

        await pipeline.encodeAvatar(Uint8List.fromList([9, 9, 9]));

        final call = codec.calls.single;
        expect(call.minWidth, avatarEdge);
        expect(call.quality, 85);
        expect(call.sampleSize, 1);
        expect(call.correctOrientation, isFalse);
      },
    );

    test('reports an unreadable photo instead of uploading it', () async {
      final codec = FakePhotoCodec(error: PlatformException(code: 'decode'));
      final pipeline = PhotoPipeline(codec: codec);

      await expectLater(
        pipeline.shrinkForEditing(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<PhotoUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('could not be opened'),
          ),
        ),
      );
    });

    test('reports a crop that cannot be encoded', () async {
      final codec = FakePhotoCodec(error: PlatformException(code: 'encode'));
      final pipeline = PhotoPipeline(codec: codec);

      await expectLater(
        pipeline.encodeAvatar(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<PhotoUnavailableException>()),
      );
    });
  });
}
