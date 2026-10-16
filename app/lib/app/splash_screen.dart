import 'package:flutter/material.dart';

import 'launch_splash.dart';
import 'theme.dart';

/// Shown while the stored session is being restored.
///
/// It exists so that no signed-in screen can build — and therefore fetch —
/// before the token that authenticates it has been attached. It draws the same
/// mark on the same background as the launch sequence that covers it, so if it
/// is ever visible it looks like part of the same screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paletteOf(context).background,
      child: const Center(child: BirthdayAppIcon()),
    );
  }
}
