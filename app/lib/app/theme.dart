import 'package:flutter/material.dart';

/// Bundled font families, declared in pubspec.yaml. They are shipped with the
/// app so typography never depends on a runtime download.
const _body = 'DMSans';
const _display = 'Fraunces';

/// Design tokens taken from the approved Figma design.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentText,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.error,
    required this.softPink,
    required this.softGreen,
    required this.heroCard,
    required this.heroCardText,
    required this.avatarTints,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentText;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color error;
  final Color softPink;
  final Color softGreen;
  final Color heroCard;
  final Color heroCardText;
  final List<Color> avatarTints;
}

const lightPalette = AppPalette(
  background: Color(0xFFF8F8F4),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFECEEE9),
  primary: Color(0xFF293D32),
  onPrimary: Color(0xFFFFFFFF),
  accent: Color(0xFFFB8269),
  accentText: Color(0xFFD75A45),
  textPrimary: Color(0xFF243029),
  textSecondary: Color(0xFF7C857F),
  border: Color(0xFFE5E5DC),
  error: Color(0xFFB94D38),
  softPink: Color(0xFFFDE5DE),
  softGreen: Color(0xFFE6F0DC),
  heroCard: Color(0xFF293D32),
  heroCardText: Color(0xFFFFFFFF),
  avatarTints: [Color(0xFFFFDDD2), Color(0xFFD8E6FF), Color(0xFFDFF4DC), Color(0xFFF1DCFF)],
);

const darkPalette = AppPalette(
  background: Color(0xFF0F1512),
  surface: Color(0xFF18201B),
  surfaceVariant: Color(0xFF222C26),
  primary: Color(0xFF4E6B57),
  onPrimary: Color(0xFFFFFFFF),
  accent: Color(0xFFFF9C86),
  accentText: Color(0xFFFF9C86),
  textPrimary: Color(0xFFEDF1EC),
  textSecondary: Color(0xFF9BA69F),
  border: Color(0xFF2B352F),
  error: Color(0xFFFF8A75),
  softPink: Color(0xFF3A2622),
  softGreen: Color(0xFF1E2A22),
  heroCard: Color(0xFF1E2A22),
  heroCardText: Color(0xFFEDF1EC),
  avatarTints: [Color(0xFF4A2F29), Color(0xFF25334A), Color(0xFF26382A), Color(0xFF35263F)],
);

/// Shared sizing tokens so every screen uses the same rhythm.
class AppSpacing {
  static const double screenPadding = 20;
  static const double cardRadius = 22;
  static const double sheetRadius = 28;
  static const double fieldRadius = 14;
  static const double minTouchTarget = 48;
}

/// Convenience accessor for the active palette inside widgets.
AppPalette paletteOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkPalette : lightPalette;

class AppTheme {
  static ThemeData light() => _build(lightPalette, Brightness.light);

  static ThemeData dark() => _build(darkPalette, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.accent,
      onSecondary: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: palette.error,
      outline: palette.border,
    );

    TextStyle body({
      required double size,
      FontWeight weight = FontWeight.w400,
      Color? color,
      double? spacing,
      double height = 1.3,
    }) =>
        TextStyle(
          fontFamily: _body,
          fontSize: size,
          fontWeight: weight,
          color: color ?? palette.textPrimary,
          letterSpacing: spacing,
          height: height,
        );

    TextStyle display({
      required double size,
      FontWeight weight = FontWeight.w700,
      double? spacing,
    }) =>
        TextStyle(
          fontFamily: _display,
          fontSize: size,
          fontWeight: weight,
          color: palette.textPrimary,
          letterSpacing: spacing,
          height: 1.15,
        );

    // Every Material text role is defined so no widget falls back to Roboto.
    final textTheme = TextTheme(
      displayLarge: display(size: 46, spacing: -1.8),
      displayMedium: display(size: 38, spacing: -1.5),
      displaySmall: display(size: 30, spacing: -1.2),
      headlineLarge: display(size: 28, spacing: -1),
      headlineMedium: display(size: 24, spacing: -0.8),
      headlineSmall: display(size: 22, spacing: -0.6),
      titleLarge: body(size: 20, weight: FontWeight.w700, spacing: -0.5),
      titleMedium: body(size: 18, weight: FontWeight.w700, spacing: -0.4),
      titleSmall: body(size: 15, weight: FontWeight.w700),
      bodyLarge: body(size: 16),
      bodyMedium: body(size: 14),
      bodySmall: body(size: 12, color: palette.textSecondary),
      labelLarge: body(size: 14, weight: FontWeight.w700),
      labelMedium: body(size: 12, weight: FontWeight.w500, color: palette.textSecondary),
      labelSmall: body(
        size: 11,
        weight: FontWeight.w700,
        color: palette.textSecondary,
        spacing: 1.2,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: palette.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: palette.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentText,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: textTheme.labelLarge?.copyWith(color: palette.accentText),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: palette.border),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.primary,
        side: BorderSide(color: palette.border),
        labelStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.surfaceVariant,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
      ),
    );
  }
}
