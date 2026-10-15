import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Pins a screen's actions above the system inset, so they are reachable without
/// scrolling to the end of a long form or detail page.
///
/// Used as `Scaffold.bottomNavigationBar`, which keeps it part of the layout:
/// the body is sized above the bar, so nothing is ever hidden behind it and no
/// screen needs to guess a magic bottom padding.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.primary, this.secondary});

  /// The screen's main action, expanded to fill the remaining width.
  final Widget primary;

  /// An optional narrower action, shown to the left of [primary].
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Material(
      color: palette.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              12,
              AppSpacing.screenPadding,
              12,
            ),
            child: Row(
              children: [
                // A Row measures an inflexible child against unbounded width,
                // which a button with an outline cannot resolve. Sizing it
                // intrinsically first keeps the slot usable for any action.
                if (secondary != null) ...[
                  IntrinsicWidth(child: secondary!),
                  const SizedBox(width: 10),
                ],
                Expanded(child: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
