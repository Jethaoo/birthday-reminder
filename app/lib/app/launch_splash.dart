import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The launch sequence from the Figma design: the app mark fades and scales in,
/// holds, then scales up and fades as the screen underneath settles into place.
///
/// Two deliberate departures from the generated code:
///
/// * the hold in the middle waits for [ready] — the stored session having been
///   restored — so the sequence cannot reveal a half-built app, and cannot cut
///   itself short on a slow device;
/// * the backdrop comes from [paletteOf], so dark mode gets the app's own
///   background. The mark itself keeps its brand colours, exactly like the
///   launcher icon, which does not change with the theme either.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.ready, required this.child});

  /// True once the app is ready to be shown. The sequence holds until then.
  final bool ready;

  final Widget child;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash> with TickerProviderStateMixin {
  /// The Figma timeline is 1800ms: 0–0.66 is the entrance and the hold, 0.66–1
  /// the exit. Split into two controllers so the hold can wait for [ready].
  static const _entranceFraction = 0.66;
  static const _entranceDuration = Duration(milliseconds: 1188);
  static const _exitDuration = Duration(milliseconds: 612);

  late final AnimationController _entrance;
  late final AnimationController _exit;
  late final AnimationController _home;

  final _ready = Completer<void>();
  bool _started = false;
  bool _reducedMotion = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: _entranceDuration);
    _exit = AnimationController(vsync: this, duration: _exitDuration);
    _home = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    if (widget.ready) _ready.complete();
  }

  @override
  void didUpdateWidget(covariant LaunchSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !_ready.isCompleted) _ready.complete();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_reducedMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } else {
      try {
        await _entrance.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }

    // If the app is never ready this simply never returns; nothing is leaked,
    // and the splash is the right thing to be looking at.
    await _ready.future;
    if (!mounted) return;

    if (!_reducedMotion) {
      try {
        await _exit.forward().orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted) return;
    }

    setState(() => _showSplash = false);
    if (!_reducedMotion) _home.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _exit.dispose();
    _home.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the actual app mounted underneath the splash, so its first frame
        // is already drawn — and its data already fetched — when it is revealed.
        ExcludeSemantics(
          excluding: _showSplash,
          child: IgnorePointer(
            ignoring: _showSplash,
            child: AnimatedBuilder(
              animation: _home,
              child: widget.child,
              builder: (context, child) {
                final progress = Curves.easeOutQuart.transform(_home.value);
                final animateHome = !_showSplash && !_reducedMotion;

                return Opacity(
                  opacity: animateHome ? lerpDouble(0.7, 1, progress)! : 1,
                  child: Transform.translate(
                    offset: Offset(0, animateHome ? lerpDouble(8, 0, progress)! : 0),
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),

        if (_showSplash)
          Positioned.fill(
            child: Semantics(
              label: 'Launching Birthday Reminder',
              liveRegion: true,
              child: AnimatedBuilder(
                animation: Listenable.merge([_entrance, _exit]),
                builder: (context, _) {
                  // The Figma timeline, remapped onto the two controllers.
                  final time =
                      _entrance.value * _entranceFraction + _exit.value * (1 - _entranceFraction);

                  // CSS equivalent: ease.
                  const fadeCurve = Cubic(0.25, 0.1, 0.25, 1);

                  // CSS equivalent: cubic-bezier(.22, 1, .36, 1).
                  const iconCurve = Cubic(0.22, 1, 0.36, 1);

                  final backgroundOpacity = _reducedMotion || time <= 0.72
                      ? 1.0
                      : 1 - fadeCurve.transform(((time - 0.72) / 0.28).clamp(0.0, 1.0));

                  double iconOpacity;
                  double iconScale;

                  if (_reducedMotion) {
                    iconOpacity = 1;
                    iconScale = 1;
                  } else if (time < 0.24) {
                    final progress = iconCurve.transform((time / 0.24).clamp(0.0, 1.0));
                    iconOpacity = progress;
                    iconScale = lerpDouble(0.78, 1, progress)!;
                  } else if (time <= 0.66) {
                    iconOpacity = 1;
                    iconScale = 1;
                  } else {
                    final progress = iconCurve.transform(((time - 0.66) / 0.34).clamp(0.0, 1.0));
                    iconOpacity = 1 - progress;
                    iconScale = lerpDouble(1, 1.16, progress)!;
                  }

                  return Opacity(
                    opacity: backgroundOpacity,
                    child: ColoredBox(
                      color: paletteOf(context).background,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Opacity(
                            opacity: iconOpacity,
                            child: Transform.scale(
                              scale: iconScale,
                              child: const BirthdayAppIcon(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// The 112 × 112 rounded-square mark from the design: the same artwork as the
/// launcher icon, so the native launch screen and this one agree.
class BirthdayAppIcon extends StatelessWidget {
  const BirthdayAppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF405B47), Color(0xFF24392D)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x18293D32), offset: Offset(0, 12), blurRadius: 28),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x18FFFFFF), width: 0.7),
      ),
      alignment: Alignment.center,
      child: const CustomPaint(size: Size(96, 96), painter: _BirthdayCakePainter()),
    );
  }
}

/// Draws the original SVG paths directly in Flutter, in the icon's own colours:
/// the mark is the same in light and dark, like the launcher icon.
class _BirthdayCakePainter extends CustomPainter {
  const _BirthdayCakePainter();

  static const coral = Color(0xFFFB8269);
  static const cream = Color(0xFFF8F8F4);
  static const paleGreen = Color(0xFFE6F0DC);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);

    final fill = Paint()..style = PaintingStyle.fill;

    // Candle flame.
    final flame = Path()
      ..moveTo(60, 16)
      ..cubicTo(50, 28, 51, 33, 60, 35)
      ..cubicTo(69, 33, 70, 28, 60, 16)
      ..close();

    canvas.drawPath(flame, fill..color = coral);

    // Candle.
    final stroke = Paint()
      ..color = cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(60, 41), const Offset(60, 58), stroke);

    // Cake body.
    final cake = Path()
      ..moveTo(33, 65)
      ..cubicTo(33, 60, 37, 56, 42, 56)
      ..lineTo(78, 56)
      ..cubicTo(83, 56, 87, 60, 87, 65)
      ..lineTo(87, 89)
      ..lineTo(33, 89)
      ..close();

    canvas.drawPath(cake, fill..color = paleGreen);

    // Coral frosting.
    final frosting = Path()
      ..moveTo(33, 68)
      ..cubicTo(38, 68, 38, 76, 44, 76)
      ..cubicTo(50, 76, 50, 68, 55, 68)
      ..cubicTo(60, 68, 60, 76, 66, 76)
      ..cubicTo(72, 76, 72, 68, 77, 68)
      ..cubicTo(82, 68, 82, 76, 87, 76)
      ..lineTo(87, 65)
      ..cubicTo(87, 60, 83, 56, 78, 56)
      ..lineTo(42, 56)
      ..cubicTo(37, 56, 33, 60, 33, 65)
      ..close();

    canvas.drawPath(frosting, fill..color = coral);

    // Cake stand.
    stroke.color = paleGreen;
    canvas.drawLine(const Offset(27, 91), const Offset(93, 91), stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BirthdayCakePainter oldDelegate) => false;
}
