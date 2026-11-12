import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import 'hud_theme.dart';
import 'hud_widgets.dart';

/// Choix du thème de l'interface, avec aperçu de chaque palette.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final current = state.data.theme;
        final system = MediaQuery.platformBrightnessOf(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Apparence')),
          body: HudBackground(
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 600 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemCount: HudThemes.all.length,
                itemBuilder: (context, i) {
                  final base = HudThemes.all[i];
                  // « Classique » s'affiche dans le mode actuel du téléphone.
                  final p = base.id == 'classique' ? HudThemes.resolve('classique', system) : base;
                  return Appear(
                    index: i,
                    child: _ThemeCard(
                      palette: p,
                      selected: current == p.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        state.setTheme(p.id);
                      },
                    ),
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.palette, required this.selected, required this.onTap});
  final HudPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    TextStyle txt(double size, Color color, [FontWeight w = FontWeight.w600]) => TextStyle(
          fontFamily: p.body,
          fontSize: p.body == null ? size * 0.92 : size,
          color: color,
          fontWeight: w,
          height: 1.15,
        );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(p.bg2, p.primary, 0.08)!, p.bg],
          ),
          border: Border.all(
            color: selected ? p.primary : p.primary.withValues(alpha: 0.2),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: p.primary.withValues(alpha: 0.35 * (p.glow + 0.3)), blurRadius: 20)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(p.name,
                    style: TextStyle(
                      fontFamily: p.display,
                      fontSize: p.display == null ? 18 : 15,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                      letterSpacing: p.display == null ? 0.2 : 1.5,
                    )),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded, color: p.primary, size: 20),
              ),
            ]),
            Expanded(
              child: Center(
                child: ArcReactor(
                  mode: selected ? ReactorMode.speaking : ReactorMode.idle,
                  size: 82,
                  color: p.primary,
                ),
              ),
            ),
            // Mini aperçu d'un volet.
            Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: p.primary.withValues(alpha: 0.08),
                border: Border.all(color: p.primary.withValues(alpha: 0.25)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [p.primary.withValues(alpha: 0.15), p.primary.withValues(alpha: 0.55)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              for (final c in [p.primary, p.accent, p.second]) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Icon(p.brightness == Brightness.light ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 16, color: p.dim),
            ]),
            const SizedBox(height: 8),
            Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(12.5, p.dim)),
          ]),
        ),
      ),
    );
  }
}
