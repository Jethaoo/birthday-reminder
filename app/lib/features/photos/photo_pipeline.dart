import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// The longest edge kept while the user pans and zooms the photo. A larger
/// source only costs memory: the stored avatar is [avatarEdge] pixels wide.
const _editingMaxEdge = 2048;

/// Edge of the square avatar that is uploaded, in pixels. Displayed avatars are
/// at most 96dp, so this is already generous at any screen density.
const avatarEdge = 1024;

/// Thrown when a picked image cannot be read or re-encoded on this device.
class PhotoUnavailableException implements Exception {
  const PhotoUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'PhotoUnavailableException: $message';
}

/// The platform JPEG encoder, behind an interface so widget tests can stand in
/// for it: `flutter_image_compress` is a plugin with no test implementation.
abstract interface class PhotoCodec {
  Future<Uint8List> reencode(
    Uint8List bytes, {
    required int minWidth,
    required int minHeight,
    required int quality,
    required int sampleSize,
    required bool correctOrientation,
  });
}

class DevicePhotoCodec implements PhotoCodec {
  const DevicePhotoCodec();

  @override
  Future<Uint8List> reencode(
    Uint8List bytes, {
    required int minWidth,
    required int minHeight,
    required int quality,
    required int sampleSize,
    required bool correctOrientation,
  }) async {
    // keepExif is false on purpose: correctOrientation bakes the rotation into
    // the pixels, and leaving the tag behind would rotate the photo twice in
    // the crop editor, which also honours EXIF orientation.
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      inSampleSize: sampleSize,
      autoCorrectionAngle: correctOrientation,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (result.isEmpty) {
      throw const PhotoUnavailableException(
        'That image could not be prepared.',
      );
    }
    return result;
  }
}

/// Turns a picked photo into something the crop editor and the upload can use.
class PhotoPipeline {
  const PhotoPipeline({this.codec = const DevicePhotoCodec()});

  final PhotoCodec codec;

  /// Uprights the photo and shrinks it to [_editingMaxEdge] before it reaches
  /// the crop editor, which decodes it again in an isolate.
  Future<Uint8List> shrinkForEditing(Uint8List source) async {
    final size = await _sourceSize(source);
    final sampleSize = size == null
        ? 2
        : sampleSizeFor(math.max(size.width, size.height).round());
    try {
      return await codec.reencode(
        source,
        minWidth: avatarEdge,
        minHeight: avatarEdge,
        quality: 92,
        sampleSize: sampleSize,
        correctOrientation: true,
      );
    } on PhotoUnavailableException {
      rethrow;
    } catch (_) {
      throw const PhotoUnavailableException(
        'That image could not be opened. Try a different photo.',
      );
    }
  }

  /// Encodes the user's square crop at upload quality. The cropped pixels are
  /// already upright, so no rotation is applied here.
  Future<Uint8List> encodeAvatar(Uint8List cropped) async {
    try {
      return await codec.reencode(
        cropped,
        minWidth: avatarEdge,
        minHeight: avatarEdge,
        quality: 85,
        sampleSize: 1,
        correctOrientation: false,
      );
    } on PhotoUnavailableException {
      rethrow;
    } catch (_) {
      throw const PhotoUnavailableException(
        'That image could not be prepared. Try another photo.',
      );
    }
  }
}

/// Subsamples large photos while they are decoded instead of after: a 48 MP
/// photo would otherwise allocate ~190 MB before being scaled down.
int sampleSizeFor(int longestEdge) {
  var sampleSize = 1;
  while (longestEdge ~/ sampleSize > _editingMaxEdge && sampleSize < 8) {
    sampleSize *= 2;
  }
  return sampleSize;
}

/// Reads the encoded dimensions without decoding any pixels. Returns null when
/// the bytes are not an image the engine can describe, in which case the
/// platform encoder is given a conservative sample size instead.
Future<ui.Size?> _sourceSize(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
