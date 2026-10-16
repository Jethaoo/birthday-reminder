import 'package:flutter/material.dart';

import 'theme.dart';

/// Shown while the stored session is being restored.
///
/// It exists so that no signed-in screen can build — and therefore fetch —
/// before the token that authenticates it has been attached.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.accentText),
        ),
      ),
    );
  }
}
