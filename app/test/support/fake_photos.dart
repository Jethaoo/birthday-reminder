import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:birthday_reminder/features/photos/photo_editor.dart';
import 'package:birthday_reminder/features/photos/photo_pipeline.dart';
import 'package:flutter/material.dart';

/// Stands in for the picker and the crop editor. Returns the queued bytes, or
/// null to simulate the user backing out at any step.
class FakePhotoEditor implements PhotoEditor {
  FakePhotoEditor({this.bytes, this.error});

  Uint8List? bytes;
  PhotoUnavailableException? error;
  int calls = 0;

  @override
  Future<Uint8List?> pickAndCrop(BuildContext context) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return bytes;
  }
}

class PhotoCodecCall {
  const PhotoCodecCall({
    required this.minWidth,
    required this.minHeight,
    required this.quality,
    required this.sampleSize,
    required this.correctOrientation,
  });

  final int minWidth;
  final int minHeight;
  final int quality;
  final int sampleSize;
  final bool correctOrientation;
}

/// Records how the pipeline asked to encode and returns the bytes unchanged, so
/// the pipeline's decisions can be asserted without a platform plugin.
class FakePhotoCodec implements PhotoCodec {
  FakePhotoCodec({this.error});

  Object? error;
  final List<PhotoCodecCall> calls = [];

  @override
  Future<Uint8List> reencode(
    Uint8List bytes, {
    required int minWidth,
    required int minHeight,
    required int quality,
    required int sampleSize,
    required bool correctOrientation,
  }) async {
    calls.add(
      PhotoCodecCall(
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        sampleSize: sampleSize,
        correctOrientation: correctOrientation,
      ),
    );
    final failure = error;
    if (failure != null) throw failure;
    return bytes;
  }
}

/// A real PNG, so the crop editor and the pipeline can decode what they are
/// given instead of working on meaningless bytes.
Future<Uint8List> testPng({int width = 96, int height = 96}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3A6B4F),
  );
  canvas.drawCircle(
    Offset(width / 2, height / 2),
    width / 4,
    Paint()..color = const Color(0xFFFB8269),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
