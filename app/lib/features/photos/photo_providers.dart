import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_editor.dart';
import 'photo_pipeline.dart';

/// The encoder is a plugin, so tests override this with a stub codec.
final photoPipelineProvider = Provider<PhotoPipeline>(
  (ref) => const PhotoPipeline(),
);

final photoEditorProvider = Provider<PhotoEditor>(
  (ref) => DevicePhotoEditor(ref.watch(photoPipelineProvider)),
);
