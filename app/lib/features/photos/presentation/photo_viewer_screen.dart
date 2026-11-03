import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Full-screen view of a birthday's or the account's private photo. Opened by
/// tapping an avatar that already has one; the photo itself is read with the
/// bearer token, like everywhere else in the app.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.relativeUrl, this.label});

  final String relativeUrl;

  /// Describes the photo to screen readers, e.g. "Sarah Tan".
  final String? label;

  static Future<void> show(
    BuildContext context,
    String relativeUrl, {
    String? label,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerScreen(relativeUrl: relativeUrl, label: label),
      ),
    );
  }

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = ref.read(apiProvider).photoBytes(widget.relativeUrl);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: FutureBuilder<Uint8List>(
                  future: _photo,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (snapshot.connectionState == ConnectionState.done &&
                        (bytes == null || bytes.isEmpty)) {
                      return const _ViewerMessage(
                        message: 'Could not load this photo.',
                      );
                    }
                    if (bytes == null || bytes.isEmpty) {
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      semanticLabel: widget.label == null
                          ? 'Photo'
                          : 'Photo of ${widget.label}',
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
