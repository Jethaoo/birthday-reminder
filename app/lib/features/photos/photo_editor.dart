import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_pipeline.dart';
import 'presentation/crop_photo_screen.dart';
import 'presentation/photo_source_sheet.dart';

export 'photo_pipeline.dart' show PhotoUnavailableException;

/// Picks a photo and lets the user crop it before anything is uploaded.
abstract interface class PhotoEditor {
  /// Returns JPEG bytes ready to upload, or null when the user cancels at the
  /// source sheet, the picker or the crop editor.
  ///
  /// Throws [PhotoUnavailableException] when the chosen image cannot be read.
  Future<Uint8List?> pickAndCrop(BuildContext context);
}

class DevicePhotoEditor implements PhotoEditor {
  DevicePhotoEditor(this._pipeline);

  final PhotoPipeline _pipeline;

  @override
  Future<Uint8List?> pickAndCrop(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return null;

    final XFile? picked;
    try {
      // No maxWidth here: the picker would decode and resize the file itself,
      // duplicating work the pipeline already does with EXIF-aware subsampling.
      picked = await ImagePicker().pickImage(source: source);
    } on PlatformException {
      throw PhotoUnavailableException(
        source == ImageSource.camera
            ? 'Could not open the camera.'
            : 'Could not open your photos.',
      );
    }
    if (picked == null) return null;

    final Uint8List raw;
    try {
      raw = await picked.readAsBytes();
    } on Exception {
      throw const PhotoUnavailableException(
        'That photo could not be read. Try a different one.',
      );
    }

    final prepared = await _pipeline.shrinkForEditing(raw);
    if (!context.mounted) return null;
    return CropPhotoScreen.show(context, prepared);
  }
}
