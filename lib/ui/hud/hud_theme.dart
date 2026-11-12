import 'package:material_ui/material_ui.dart';

import 'hud_widgets.dart';

/// Palette « hologramme » futuriste.
class Hud {
  static const bg = Color(0xFF02070D);
  static const bg2 = Color(0xFF061420);
  static const cyan = Color(0xFF29E7FF);
  static const cyanSoft = Color(0xFF7FF3FF);
  static const blue = Color(0xFF1A8CFF);
  static const amber = Color(0xFFFFB12A);
  static const violet = Color(0xFFC58BFF);
  static const red = Color(0xFFFF4D5E);
  static const text = Color(0xFFDDF9FF);
  static const dim = Color(0xFF5C8FA3);
  static const line = Color(0x3329E7FF);

  static const display = 'Orbitron';
  static const body = 'Rajdhani';

  static TextStyle label({double size = 11, Color color = cyan, double spacing = 2.4, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: display, fontSize: size, color: color, letterSpacing: spacing, fontWeight: weight);

  static TextStyle bodyText({double size = 16, Color color = text, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: body, fontSize: size, color: color, fontWeight: weight, height: 1.25);

  static List<Shadow> glow(Color c, [double r = 12]) => [Shadow(color: c.withValues(alpha: 0.8), blurRadius: r)];

  /// Thème des écrans secondaires (comptes, réglages…).
  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
    ).copyWith(
      primary: cyan,
      onPrimary: bg,
      secondary: amber,
      surface: bg,
      surfaceContainerLow: const Color(0xFF071824),
      surfaceContainerHighest: const Color(0xFF0B2433),
      error: red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark, fontFamily: body);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SmoothPageTransitionsBuilder(),
        TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cyan,
        titleTextStyle: bodyText(size: 20, weight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF071824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF071824),
        labelStyle: const TextStyle(color: dim),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cyan)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: bg,
          minimumSize: const Size(0, 52),
          textStyle: bodyText(size: 16, color: bg, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0B2433),
        contentTextStyle: bodyText(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF061420)),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF061420)),
    );
  }
}
