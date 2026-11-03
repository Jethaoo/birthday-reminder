import 'dart:async';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../photo_pipeline.dart';
import '../photo_providers.dart';

/// Photo editors stay dark in both themes: the photo carries the contrast, and
/// a white sheet would wash out a pale portrait.
const _editorBackground = Color(0xFF0E1311);
const _maskColor = Color(0xB3000000);

/// Warm near-black ink on the coral action, which keeps the label readable
/// where white would not be.
const _inkOnAccent = Color(0xFF2A1613);

/// Squares a photo before it is uploaded. Avatars are shown in a circle, so the
/// crop is locked to 1:1 and the user only pans and zooms inside it.
class CropPhotoScreen extends ConsumerStatefulWidget {
  const CropPhotoScreen({super.key, required this.image});

  /// An uprighted, downscaled copy of the picked photo.
  final Uint8List image;

  /// Returns the cropped, upload-ready JPEG, or null if the user backs out.
  static Future<Uint8List?> show(BuildContext context, Uint8List image) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CropPhotoScreen(image: image),
      ),
    );
  }

  @override
  ConsumerState<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends ConsumerState<CropPhotoScreen> {
  /// Replaced on Reset: a fresh controller and key give the crop widget a new
  /// state, which is the only reliable way back to the opening framing. Asking
  /// the existing widget to re-apply the same zoom leaves the photo at fit size
  /// instead of cover, because it short-circuits on an unchanged scale.
  CropController _controller = CropController();
  Key _editorKey = UniqueKey();

  /// The photo has been parsed and can be cropped.
  bool _ready = false;

  /// A crop is being encoded; another tap would queue a second one.
  bool _cropping = false;

  /// The user has panned or zoomed, so Reset has something to undo. The crop
  /// widget records a history entry for every gesture, which is the only
  /// reliable signal: comparing rects reports "moved" for the initial fit.
  bool _moved = false;

  void _handleStatus(CropStatus status) {
    final ready = status == CropStatus.ready;
    final cropping = status == CropStatus.cropping;
    if (ready == _ready && cropping == _cropping) return;
    if (!mounted) return;
    setState(() {
      _ready = ready;
      _cropping = cropping;
    });
  }

  void _handleHistory(History history) {
    final moved = history.undoCount > 0;
    if (moved == _moved || !mounted) return;
    setState(() => _moved = moved);
  }

  void _reset() {
    setState(() {
      _moved = false;
      // The rebuilt editor reports ready again once it has parsed the photo.
      _ready = false;
      _cropping = false;
      _controller = CropController();
      _editorKey = UniqueKey();
    });
  }

  void _usePhoto() {
    if (!_ready || _cropping) return;
    setState(() => _cropping = true);
    _controller.crop();
  }

  Future<void> _handleCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final bytes = await ref
              .read(photoPipelineProvider)
              .encodeAvatar(croppedImage);
          if (!mounted) return;
          Navigator.of(context).pop(bytes);
        } on PhotoUnavailableException catch (error) {
          _showError(error.message);
        }
      case CropFailure():
        _showError('Could not crop that photo. Try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _editorBackground,
        body: SafeArea(
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              Expanded(
                // The square is the widest thing on screen; without the inset
                // its corner handles are clipped by the screen edge.
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Crop(
                    key: _editorKey,
                    image: widget.image,
                    controller: _controller,
                    onCropped: (result) => unawaited(_handleCropped(result)),
                    aspectRatio: 1,
                    interactive: true,
                    fixCropRect: true,
                    baseColor: _editorBackground,
                    maskColor: _maskColor,
                    radius: 4,
                    cornerDotBuilder: (size, edge) =>
                        _CornerBracket(size: size, edge: edge),
                    progressIndicator: const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    overlayBuilder: (_, _) => const _CropGuide(),
                    onHistoryChanged: _handleHistory,
                    onStatusChanged: _handleStatus,
                  ),
                ),
              ),
              _Footer(
                accent: paletteOf(context).accent,
                busy: _cropping,
                canReset: _moved && !_cropping,
                canUse: _ready && !_cropping,
                onReset: _reset,
                onUse: _usePhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'Cancel',
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Crop photo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.accent,
    required this.busy,
    required this.canReset,
    required this.canUse,
    required this.onReset,
    required this.onUse,
  });

  final Color accent;
  final bool busy;
  final bool canReset;
  final bool canUse;
  final VoidCallback onReset;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        4,
        AppSpacing.screenPadding,
        16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Drag to reposition · pinch to zoom',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: canReset ? onReset : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                  minimumSize: const Size(0, 52),
                ),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: canUse ? onUse : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: _inkOnAccent,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.12,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.4,
                    ),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.fieldRadius,
                      ),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Text(
                          'Use photo',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thirds grid plus the circle the photo will be shown in, so the user sees the
/// avatar before committing to the crop.
class _CropGuide extends StatelessWidget {
  const _CropGuide();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _CropGuidePainter());
  }
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final fraction in const [1 / 3, 2 / 3]) {
      final x = size.width * fraction;
      final y = size.height * fraction;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _CropGuidePainter oldDelegate) => false;
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.size, required this.edge});

  final double size;
  final EdgeAlignment edge;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CornerBracketPainter(edge),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter(this.edge);

  final EdgeAlignment edge;

  @override
  void paint(Canvas canvas, Size size) {
    final left =
        edge == EdgeAlignment.topLeft || edge == EdgeAlignment.bottomLeft;
    final top = edge == EdgeAlignment.topLeft || edge == EdgeAlignment.topRight;
    final inset = size.width * 0.18;
    final arm = size.width * 0.4;
    final x = left ? inset : size.width - inset;
    final y = top ? inset : size.height - inset;
    canvas.drawPath(
      Path()
        ..moveTo(x + (left ? arm : -arm), y)
        ..lineTo(x, y)
        ..lineTo(x, y + (top ? arm : -arm)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.edge != edge;
}
