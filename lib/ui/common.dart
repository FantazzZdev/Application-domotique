import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/widget_bridge.dart';

/// Icônes disponibles pour les raccourcis (mêmes clés côté widgets natifs).
const Map<String, IconData> shortcutIcons = {
  'up': Icons.arrow_upward_rounded,
  'down': Icons.arrow_downward_rounded,
  'stop': Icons.stop_rounded,
  'shutter': Icons.roller_shades,
  'gate': Icons.fence,
  'garage': Icons.garage,
  'light': Icons.lightbulb,
  'home': Icons.home_rounded,
};

IconData iconFor(String key) => shortcutIcons[key] ?? Icons.touch_app;

IconData deviceIcon(DeviceKind kind) {
  switch (kind) {
    case DeviceKind.shutter:
      return Icons.roller_shades;
    case DeviceKind.gate:
      return Icons.fence;
    case DeviceKind.garage:
      return Icons.garage;
    case DeviceKind.light:
      return Icons.lightbulb;
    case DeviceKind.other:
      return Icons.devices_other;
  }
}

Color accountColor(Account? a) => Color(accountColors[(a?.colorIndex ?? 0) % accountColors.length]);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4F7CFF), brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.color});
  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Row(
        children: [
          if (color != null) ...[
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(text, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
