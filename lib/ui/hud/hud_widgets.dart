import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'hud_theme.dart';

// ======================================================================
// Fond : grille holographique, halo central, ligne de balayage.
// ======================================================================

class HudBackground extends StatefulWidget {
  const HudBackground({super.key, required this.child});
  final Widget child;

  @override
  State<HudBackground> createState() => _HudBackgroundState();
}

class _HudBackgroundState extends State<HudBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _GridPainter(_c.value)),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.45),
          radius: 1.1,
          colors: [Color(0xFF0A2A3D), Hud.bg2, Hud.bg],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = Hud.cyan.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Ligne de balayage.
    final y = size.height * t;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 60, size.width, 60),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Hud.cyan.withValues(alpha: 0), Hud.cyan.withValues(alpha: 0.05)],
        ).createShader(Rect.fromLTWH(0, y - 60, size.width, 60)),
    );
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = Hud.cyan.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.t != t;
}

// ======================================================================
// Panneau à coins biseautés.
// ======================================================================

class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.title,
    this.accent = Hud.cyan,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  final Widget child;
  final String? title;
  final Color accent;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PanelPainter(accent),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(children: [
                Container(width: 6, height: 6, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title!.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: Hud.label(size: 11, color: accent).copyWith(shadows: Hud.glow(accent, 8))),
                ),
                ?trailing,
              ]),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

Path chamfer(Rect r, double c) => Path()
  ..moveTo(r.left + c, r.top)
  ..lineTo(r.right - c * 2, r.top)
  ..lineTo(r.right, r.top + c * 2)
  ..lineTo(r.right, r.bottom - c)
  ..lineTo(r.right - c, r.bottom)
  ..lineTo(r.left + c * 2, r.bottom)
  ..lineTo(r.left, r.bottom - c * 2)
  ..lineTo(r.left, r.top + c)
  ..close();

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(0.5);
    final path = chamfer(r, 8);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.09), const Color(0x22061420)],
        ).createShader(r),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.35),
    );
    // Équerres lumineuses.
    final g = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top + 22)
          ..lineTo(r.left, r.top + 8)
          ..lineTo(r.left + 8, r.top)
          ..lineTo(r.left + 26, r.top),
        g);
    canvas.drawPath(
        Path()
          ..moveTo(r.right, r.bottom - 22)
          ..lineTo(r.right, r.bottom - 8)
          ..lineTo(r.right - 8, r.bottom)
          ..lineTo(r.right - 26, r.bottom),
        g);
  }

  @override
  bool shouldRepaint(_PanelPainter old) => old.accent != accent;
}

// ======================================================================
// Réacteur ARK : cœur visuel de Jarvis.
// ======================================================================

enum ReactorMode { idle, listening, thinking, speaking }

class ArcReactor extends StatefulWidget {
  const ArcReactor({super.key, required this.mode, this.level = 0, this.size = 230});
  final ReactorMode mode;
  final double level;
  final double size;

  @override
  State<ArcReactor> createState() => _ArcReactorState();
}

class _ArcReactorState extends State<ArcReactor> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  double _smooth = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            _smooth += (widget.level - _smooth) * 0.25;
            return CustomPaint(painter: _ReactorPainter(_c.value * 60, widget.mode, _smooth));
          },
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  _ReactorPainter(this.t, this.mode, this.level);
  final double t; // secondes
  final ReactorMode mode;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide / 2;
    final color = switch (mode) {
      ReactorMode.thinking => Hud.amber,
      _ => Hud.cyan,
    };
    final speed = switch (mode) {
      ReactorMode.idle => 0.25,
      ReactorMode.listening => 0.6,
      ReactorMode.thinking => 2.2,
      ReactorMode.speaking => 0.9,
    };
    final pulse = 0.5 + 0.5 * math.sin(t * (mode == ReactorMode.speaking ? 9 : 2.2));
    final energy = switch (mode) {
      ReactorMode.idle => 0.35 + 0.1 * pulse,
      ReactorMode.listening => 0.55 + 0.45 * level,
      ReactorMode.thinking => 0.7 + 0.2 * pulse,
      ReactorMode.speaking => 0.6 + 0.35 * pulse,
    };

    // Halo.
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.30 * energy),
          color.withValues(alpha: 0.06 * energy),
          color.withValues(alpha: 0),
        ], stops: const [0, 0.55, 1])
            .createShader(Rect.fromCircle(center: c, radius: R)),
    );

    Paint stroke(double w, double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = color.withValues(alpha: a)
      ..strokeCap = StrokeCap.butt;

    // Anneau externe gradué.
    final r1 = R * 0.95;
    canvas.drawCircle(c, r1, stroke(1, 0.35));
    for (var i = 0; i < 72; i++) {
      final a = i / 72 * 2 * math.pi + t * 0.05 * speed;
      final long = i % 6 == 0;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r1;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r1 - (long ? 10 : 4));
      canvas.drawLine(p1, p2, stroke(long ? 2 : 1, long ? 0.8 : 0.4));
    }

    // Segments tournants.
    final r2 = R * 0.80;
    final rot2 = t * 0.6 * speed;
    for (var i = 0; i < 3; i++) {
      final start = rot2 + i * 2 * math.pi / 3;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r2), start, 1.4, false, stroke(5, 0.85 * energy + 0.1));
    }
    // Anneau pointillé inverse.
    final r3 = R * 0.68;
    final rot3 = -t * 0.9 * speed;
    for (var i = 0; i < 24; i++) {
      final s = rot3 + i * 2 * math.pi / 24;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r3), s, 0.14, false, stroke(3, 0.55));
    }

    // Spectre audio pendant l'écoute / la parole.
    if (mode == ReactorMode.listening || mode == ReactorMode.speaking) {
      final rb = R * 0.56;
      for (var i = 0; i < 48; i++) {
        final a = i / 48 * 2 * math.pi;
        final wave = (math.sin(i * 1.7 + t * 8) * 0.5 + 0.5) * (math.sin(i * 0.6 - t * 5) * 0.5 + 0.5);
        final amp = mode == ReactorMode.listening ? level : 0.35 + 0.3 * pulse;
        final len = 3 + 16 * amp * wave;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * rb, c + dir * (rb + len), stroke(2, 0.75));
      }
    }

    // Triangle intérieur (réacteur Mark VI).
    final r4 = R * 0.42;
    final tri = Path();
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 3 + t * 0.15 * speed;
      final p = c + Offset(math.cos(a), math.sin(a)) * r4;
      i == 0 ? tri.moveTo(p.dx, p.dy) : tri.lineTo(p.dx, p.dy);
    }
    tri.close();
    canvas.drawPath(tri, stroke(2.5, 0.8));
    canvas.drawCircle(c, r4, stroke(1.2, 0.5));

    // Cœur lumineux.
    final core = R * (0.2 + 0.05 * energy);
    canvas.drawCircle(
      c,
      core * 1.8,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0),
        ], stops: const [0, 0.35, 1])
            .createShader(Rect.fromCircle(center: c, radius: core * 1.8)),
    );
    canvas.drawCircle(c, core * 0.75, Paint()..color = Colors.white.withValues(alpha: 0.85 * energy + 0.15));
  }

  @override
  bool shouldRepaint(_ReactorPainter old) => true;
}

// ======================================================================
// Curseur de volet : glisser vers le haut / le bas.
// ======================================================================

class ShutterSlider extends StatefulWidget {
  const ShutterSlider({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.busy = false,
    this.accent = Hud.cyan,
    this.height = 170,
  });

  /// 0 = fermé, 100 = ouvert. Null = inconnu.
  final double? value;
  final String label;
  final ValueChanged<int> onChanged;
  final bool busy;
  final Color accent;
  final double height;

  @override
  State<ShutterSlider> createState() => _ShutterSliderState();
}

class _ShutterSliderState extends State<ShutterSlider> {
  double? _drag;
  int _lastTick = -1;

  void _update(Offset local) {
    final v = (1 - (local.dy / widget.height)).clamp(0.0, 1.0) * 100;
    final snapped = (v / 5).round() * 5.0;
    final tick = (snapped / 10).floor();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    setState(() => _drag = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _drag ?? widget.value ?? 0;
    final pct = _drag != null ? '${_drag!.round()}%' : (widget.value == null ? '--' : '${widget.value!.round()}%');
    return SizedBox(
      width: 78,
      child: Column(children: [
        Text(pct,
            style: Hud.label(size: 15, color: _drag != null ? Hud.amber : widget.accent)
                .copyWith(shadows: Hud.glow(_drag != null ? Hud.amber : widget.accent, 10))),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _update(d.localPosition),
          onVerticalDragUpdate: (d) => _update(d.localPosition),
          onVerticalDragEnd: (_) {
            final v = _drag;
            setState(() => _drag = null);
            if (v != null) {
              HapticFeedback.mediumImpact();
              widget.onChanged(v.round());
            }
          },
          onTapUp: (d) {
            _update(d.localPosition);
            final v = _drag!;
            setState(() => _drag = null);
            HapticFeedback.mediumImpact();
            widget.onChanged(v.round());
          },
          child: SizedBox(
            width: 54,
            height: widget.height,
            child: CustomPaint(
              painter: _ShutterPainter(shown / 100, widget.accent, _drag != null, widget.busy),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(widget.label.toUpperCase(),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Hud.bodyText(size: 12, color: Hud.text.withValues(alpha: 0.8), weight: FontWeight.w600)
                .copyWith(letterSpacing: 1)),
      ]),
    );
  }
}

class _ShutterPainter extends CustomPainter {
  _ShutterPainter(this.open, this.accent, this.dragging, this.busy);
  final double open; // 0..1
  final Color accent;
  final bool dragging;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final color = dragging ? Hud.amber : accent;
    final frame = chamfer(r.deflate(1), 6);
    canvas.drawPath(frame, Paint()..color = color.withValues(alpha: 0.05));
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );
    // Partie fermée : lames du volet (depuis le haut).
    final closedH = (size.height - 8) * (1 - open);
    final inner = r.deflate(5);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(inner.left, inner.top, inner.width, closedH));
    for (double y = inner.top; y < inner.top + closedH; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(inner.left, y, inner.width, 6),
        Paint()..color = color.withValues(alpha: busy ? 0.35 : 0.55),
      );
    }
    canvas.restore();
    // Zone ouverte : lumière.
    final openRect = Rect.fromLTWH(inner.left, inner.top + closedH, inner.width, inner.height - closedH);
    canvas.drawRect(
      openRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.02)],
        ).createShader(openRect),
    );
    // Barre de position.
    final y = inner.top + closedH;
    canvas.drawLine(
      Offset(r.left - 4, y),
      Offset(r.right + 4, y),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
    // Graduations latérales.
    final tick = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 0; i <= 10; i++) {
      final ty = inner.top + inner.height * i / 10;
      canvas.drawLine(Offset(r.right + 3, ty), Offset(r.right + (i % 5 == 0 ? 9 : 6), ty), tick);
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter o) =>
      o.open != open || o.dragging != dragging || o.busy != busy || o.accent != accent;
}

// ======================================================================
// Maintenir pour activer (portail, garage).
// ======================================================================

class HoldActivator extends StatefulWidget {
  const HoldActivator({
    super.key,
    required this.label,
    required this.onActivate,
    this.icon = Icons.fence,
    this.busy = false,
    this.accent = Hud.cyan,
    this.size = 120,
  });

  final String label;
  final VoidCallback onActivate;
  final IconData icon;
  final bool busy;
  final Color accent;
  final double size;

  @override
  State<HoldActivator> createState() => _HoldActivatorState();
}

class _HoldActivatorState extends State<HoldActivator> with TickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onActivate();
        _flash.forward(from: 0);
        _hold.value = 0;
      }
    });
  late final _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _hold.dispose();
    _flash.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTapDown: (_) {
          if (widget.busy) return;
          HapticFeedback.lightImpact();
          _hold.forward();
        },
        onTapUp: (_) => _hold.reverse(),
        onTapCancel: () => _hold.reverse(),
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hold, _flash, _spin]),
            builder: (_, _) => CustomPaint(
              painter: _HoldPainter(_hold.value, _flash.value, _spin.value, widget.busy, widget.accent),
              child: Center(
                child: Icon(widget.icon,
                    size: widget.size * 0.3,
                    color: Color.lerp(widget.accent, Colors.white, _hold.value),
                    shadows: Hud.glow(widget.accent, 14)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(widget.label.toUpperCase(),
          textAlign: TextAlign.center, style: Hud.bodyText(size: 13, weight: FontWeight.w700).copyWith(letterSpacing: 1.5)),
      Text(widget.busy ? 'TRANSMISSION…' : 'MAINTENIR',
          style: Hud.label(size: 9, color: widget.busy ? Hud.amber : Hud.dim, spacing: 2)),
    ]);
  }
}

class _HoldPainter extends CustomPainter {
  _HoldPainter(this.progress, this.flash, this.spin, this.busy, this.accent);
  final double progress, flash, spin;
  final bool busy;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide / 2 - 4;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.35);
    canvas.drawCircle(c, R, base);
    canvas.drawCircle(c, R * 0.72, base);
    // Rotation lente des segments.
    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = (busy ? Hud.amber : accent).withValues(alpha: 0.6);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: R * 0.86),
          spin * 2 * math.pi * (busy ? 3 : 1) + i * math.pi / 2, 0.8, false, seg);
    }
    // Progression du maintien.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: R),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
      canvas.drawCircle(c, R * 0.7, Paint()..color = accent.withValues(alpha: 0.15 * progress));
    }
    // Onde de choc à l'activation.
    if (flash > 0 && flash < 1) {
      canvas.drawCircle(
        c,
        R * (1 + flash * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - flash)
          ..color = accent.withValues(alpha: 1 - flash),
      );
    }
  }

  @override
  bool shouldRepaint(_HoldPainter o) => true;
}

// ======================================================================
// Interrupteur (lumières).
// ======================================================================

class HudSwitch extends StatelessWidget {
  const HudSwitch({super.key, required this.on, required this.label, required this.onChanged, this.busy = false});
  final bool on;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = on ? Hud.amber : Hud.dim;
    return GestureDetector(
      onTap: busy
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onChanged(!on);
            },
      child: SizedBox(
        width: 92,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
              color: color.withValues(alpha: on ? 0.18 : 0.04),
              boxShadow: on ? [BoxShadow(color: Hud.amber.withValues(alpha: 0.45), blurRadius: 22)] : null,
            ),
            child: Icon(on ? Icons.lightbulb : Icons.lightbulb_outline, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Hud.bodyText(size: 12, weight: FontWeight.w600).copyWith(letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ======================================================================
// Protocole (raccourci) : tuile à coins biseautés.
// ======================================================================

class ProtocolTile extends StatelessWidget {
  const ProtocolTile({
    super.key,
    required this.label,
    required this.sub,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.onLongPress,
    this.busy = false,
  });

  final String label;
  final String sub;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap();
            },
      onLongPress: onLongPress,
      child: CustomPaint(
        painter: _PanelPainter(busy ? Hud.amber : accent),
        child: SizedBox(
          width: 148,
          height: 92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 22, color: accent, shadows: Hud.glow(accent, 10)),
                const Spacer(),
                busy
                    ? SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Hud.amber),
                      )
                    : Text('EXEC', style: Hud.label(size: 8, color: Hud.dim)),
              ]),
              const Spacer(),
              Text(label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Hud.bodyText(size: 14, weight: FontWeight.w700).copyWith(letterSpacing: 0.8, height: 1.05)),
              Text(sub.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Hud.label(size: 8, color: accent)),
            ]),
          ),
        ),
      ),
    );
  }
}
