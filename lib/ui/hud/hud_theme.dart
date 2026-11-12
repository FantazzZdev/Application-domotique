import 'package:material_ui/material_ui.dart';

import 'hud_widgets.dart';

/// Une palette de couleurs (un thème de l'app).
class HudPalette {
  const HudPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.bg,
    required this.bg2,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.second,
    required this.text,
    required this.dim,
    this.red = const Color(0xFFFF4D5E),
    this.display = 'Orbitron',
    this.body = 'Rajdhani',
    this.glow = 1.0,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color bg; // fond
  final Color bg2; // fond des cartes
  final Color primary; // couleur principale (Orion, boutons…)
  final Color primarySoft;
  final Color accent; // action en cours, « Tous les volets »…
  final Color second; // couleur de Nova
  final Color text;
  final Color dim;
  final Color red;
  final String? display; // police des titres (null = police du système)
  final String? body;
  final double glow; // intensité des halos
}

/// Les thèmes proposés. « classique » suit le mode clair / sombre du téléphone.
class HudThemes {
  static const classicDark = HudPalette(
    id: 'classique',
    name: 'Classique',
    description: 'Sobre, suit le mode clair ou sombre du téléphone',
    brightness: Brightness.dark,
    bg: Color(0xFF111418),
    bg2: Color(0xFF1A1F26),
    primary: Color(0xFF7AA2FF),
    primarySoft: Color(0xFFB4C9FF),
    accent: Color(0xFFFFB547),
    second: Color(0xFFD29BFF),
    text: Color(0xFFE9EDF4),
    dim: Color(0xFF8C95A5),
    display: null,
    body: null,
    glow: 0.25,
  );

  static const classicLight = HudPalette(
    id: 'classique',
    name: 'Classique',
    description: 'Sobre, suit le mode clair ou sombre du téléphone',
    brightness: Brightness.light,
    bg: Color(0xFFF3F5F9),
    bg2: Color(0xFFFFFFFF),
    primary: Color(0xFF3A63E8),
    primarySoft: Color(0xFF3A63E8),
    accent: Color(0xFFD97A00),
    second: Color(0xFF8A44E6),
    text: Color(0xFF151A24),
    dim: Color(0xFF667085),
    red: Color(0xFFD92D3A),
    display: null,
    body: null,
    glow: 0.15,
  );

  static const all = <HudPalette>[
    classicDark,
    HudPalette(
      id: 'holo',
      name: 'Holo',
      description: 'Hologramme cyan, l\'ambiance d\'origine',
      brightness: Brightness.dark,
      bg: Color(0xFF02070D),
      bg2: Color(0xFF061420),
      primary: Color(0xFF29E7FF),
      primarySoft: Color(0xFF7FF3FF),
      accent: Color(0xFFFFB12A),
      second: Color(0xFFC58BFF),
      text: Color(0xFFDDF9FF),
      dim: Color(0xFF5C8FA3),
    ),
    HudPalette(
      id: 'armure',
      name: 'Armure',
      description: 'Rouge et or, façon armure high-tech',
      brightness: Brightness.dark,
      bg: Color(0xFF0C0405),
      bg2: Color(0xFF1C0A0C),
      primary: Color(0xFFFFC548),
      primarySoft: Color(0xFFFFE3A3),
      accent: Color(0xFFFF4B3E),
      second: Color(0xFFFF8E6E),
      text: Color(0xFFFFF2E2),
      dim: Color(0xFFA6806F),
      red: Color(0xFFFF6B5E),
    ),
    HudPalette(
      id: 'neon',
      name: 'Néon',
      description: 'Rose et bleu électrique, esprit années 80',
      brightness: Brightness.dark,
      bg: Color(0xFF0A0418),
      bg2: Color(0xFF170A30),
      primary: Color(0xFFFF3DCB),
      primarySoft: Color(0xFFFF9EE9),
      accent: Color(0xFF2DE2FF),
      second: Color(0xFFB98CFF),
      text: Color(0xFFFCEBFF),
      dim: Color(0xFF8E70A8),
    ),
    HudPalette(
      id: 'terminal',
      name: 'Terminal',
      description: 'Vert phosphore sur noir, pour les hackers',
      brightness: Brightness.dark,
      bg: Color(0xFF010803),
      bg2: Color(0xFF05150B),
      primary: Color(0xFF3BFF6F),
      primarySoft: Color(0xFFA8FFC0),
      accent: Color(0xFFE6FF5A),
      second: Color(0xFF5AFFD8),
      text: Color(0xFFD9FFE3),
      dim: Color(0xFF4F8B5F),
    ),
    HudPalette(
      id: 'cosmos',
      name: 'Cosmos',
      description: 'Violet profond et lueurs d\'étoiles',
      brightness: Brightness.dark,
      bg: Color(0xFF05040F),
      bg2: Color(0xFF0F0C26),
      primary: Color(0xFF9F8DFF),
      primarySoft: Color(0xFFD0C7FF),
      accent: Color(0xFFFFC66B),
      second: Color(0xFFFF8FD2),
      text: Color(0xFFEDEBFF),
      dim: Color(0xFF7B77A8),
    ),
    HudPalette(
      id: 'glacier',
      name: 'Glacier',
      description: 'Clair et lumineux, bleu glacier',
      brightness: Brightness.light,
      bg: Color(0xFFEDF3F8),
      bg2: Color(0xFFFFFFFF),
      primary: Color(0xFF0091C2),
      primarySoft: Color(0xFF00739C),
      accent: Color(0xFFE5841F),
      second: Color(0xFF8B5CF6),
      text: Color(0xFF0F1B2A),
      dim: Color(0xFF5B6B80),
      red: Color(0xFFD92D3A),
      glow: 0.3,
    ),
  ];

  /// Palette à utiliser pour un thème donné et le mode du téléphone.
  static HudPalette resolve(String id, Brightness system) {
    if (id == 'classique') return system == Brightness.light ? classicLight : classicDark;
    return all.firstWhere((p) => p.id == id, orElse: () => all[1]);
  }
}

/// Couleurs et styles courants (changent avec le thème choisi).
class Hud {
  static HudPalette palette = HudThemes.all[1];

  static Color bg = palette.bg;
  static Color bg2 = palette.bg2;
  static Color cyan = palette.primary;
  static Color cyanSoft = palette.primarySoft;
  static Color amber = palette.accent;
  static Color violet = palette.second;
  static Color red = palette.red;
  static Color text = palette.text;
  static Color dim = palette.dim;
  static Color line = palette.primary.withValues(alpha: 0.2);
  static String? display = palette.display;
  static String? body = palette.body;

  static bool get isLight => palette.brightness == Brightness.light;

  static void apply(HudPalette p) {
    palette = p;
    bg = p.bg;
    bg2 = p.bg2;
    cyan = p.primary;
    cyanSoft = p.primarySoft;
    amber = p.accent;
    violet = p.second;
    red = p.red;
    text = p.text;
    dim = p.dim;
    line = p.primary.withValues(alpha: p.brightness == Brightness.light ? 0.28 : 0.2);
    display = p.display;
    body = p.body;
  }

  static TextStyle label({double size = 11, Color? color, double spacing = 2.4, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: display,
        fontSize: display == null ? size * 1.1 : size,
        color: color ?? cyan,
        letterSpacing: display == null ? spacing * 0.4 : spacing,
        fontWeight: weight,
      );

  static TextStyle bodyText({double size = 16, Color? color, FontWeight weight = FontWeight.w500}) => TextStyle(
        fontFamily: body,
        fontSize: body == null ? size * 0.92 : size,
        color: color ?? text,
        fontWeight: weight,
        height: 1.25,
      );

  static List<Shadow> glow(Color c, [double r = 12]) =>
      palette.glow <= 0.01 ? const [] : [Shadow(color: c.withValues(alpha: 0.8 * palette.glow), blurRadius: r)];

  /// Thème Material des écrans (réglages, comptes…), aux couleurs du thème.
  static ThemeData theme() {
    final light = isLight;
    final card = Color.lerp(bg2, cyan, light ? 0.02 : 0.04)!;
    final scheme = ColorScheme.fromSeed(seedColor: cyan, brightness: palette.brightness).copyWith(
      primary: cyan,
      onPrimary: light ? Colors.white : bg,
      secondary: amber,
      surface: bg,
      onSurface: text,
      onSurfaceVariant: dim,
      surfaceContainerLow: card,
      surfaceContainerHighest: Color.lerp(bg2, cyan, 0.1),
      error: red,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: palette.brightness,
      fontFamily: body,
    );
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
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: TextStyle(color: dim),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cyan)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: light ? Colors.white : bg,
          minimumSize: const Size(0, 52),
          textStyle: bodyText(size: 16, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(bg2, cyan, 0.12),
        contentTextStyle: bodyText(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: line)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: bg2),
      dialogTheme: DialogThemeData(backgroundColor: bg2),
      popupMenuTheme: PopupMenuThemeData(color: bg2),
    );
  }
}
