import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';

/// Initial-based avatar with a stable tint per person.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.initials,
    required this.colorSeed,
    this.size = 48,
    this.photoUrl,
  });

  final String initials;
  final int colorSeed;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final tint = palette.avatarTints[colorSeed.abs() % palette.avatarTints.length];

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AuthenticatedPhoto(
            relativeUrl: photoUrl!,
            fallback: _Initials(initials: initials, tint: tint, size: size, palette: palette),
          ),
        ),
      );
    }

    return _Initials(initials: initials, tint: tint, size: size, palette: palette);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.initials,
    required this.tint,
    required this.size,
    required this.palette,
  });

  final String initials;
  final Color tint;
  final double size;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'DMSans',
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

/// Loads a private photo with the bearer token, falling back to initials.
class AuthenticatedPhoto extends ConsumerStatefulWidget {
  const AuthenticatedPhoto({super.key, required this.relativeUrl, required this.fallback});

  final String relativeUrl;
  final Widget fallback;

  @override
  ConsumerState<AuthenticatedPhoto> createState() => _AuthenticatedPhotoState();
}

class _AuthenticatedPhotoState extends ConsumerState<AuthenticatedPhoto> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).photoBytes(widget.relativeUrl);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativeUrl != widget.relativeUrl) {
      _future = ref.read(apiProvider).photoBytes(widget.relativeUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return widget.fallback;
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      },
    );
  }
}
