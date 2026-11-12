import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'hud_theme.dart';

// ======================================================================
// Fond : grille holographique, halo central, ligne de balayage.
// ======================================================================

class HudBackground extends StatelessWidget {
  const HudBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _GridPainter()))),
      child,
    ]);
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [Color(0xFF0B2233), Hud.bg2, Hud.bg],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
    // Trame très discrète.
    final dot = Paint()..color = Hud.cyan.withValues(alpha: 0.05);
    const step = 26.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
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
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final Widget child;
  final String? title;
  final Color accent;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(Hud.bg2, accent, 0.07)!, const Color(0xFF07131D)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.05), blurRadius: 24, spreadRadius: -4)],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title!,
                      overflow: TextOverflow.ellipsis,
                      style: Hud.bodyText(size: 18, weight: FontWeight.w700).copyWith(letterSpacing: 0.3)),
                ),
                ?trailing,
              ]),
              const SizedBox(height: 14),
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

// ======================================================================
// Réacteur : cœur visuel de l'assistant.
// ======================================================================

enum ReactorMode { idle, listening, thinking, speaking }

class ArcReactor extends StatefulWidget {
  const ArcReactor({super.key, required this.mode, this.level = 0, this.size = 230, this.color = Hud.cyan});
  final ReactorMode mode;
  final Color color;
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
            return CustomPaint(painter: _ReactorPainter(_c.value * 60, widget.mode, _smooth, widget.color));
          },
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  _ReactorPainter(this.t, this.mode, this.level, this.base);
  final double t; // secondes
  final ReactorMode mode;
  final double level;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide / 2;
    final color = switch (mode) {
      ReactorMode.thinking => Hud.amber,
      _ => base,
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
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.04)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: busy
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onTap();
                },
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: busy ? Hud.amber : accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: (busy ? Hud.amber : accent).withValues(alpha: 0.45), blurRadius: 14)],
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Hud.bg),
                      )
                    : Icon(icon, size: 22, color: Hud.bg),
              ),
              const Spacer(),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Hud.bodyText(size: 15, weight: FontWeight.w700).copyWith(height: 1.05)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Hud.bodyText(size: 12, color: Hud.dim)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Volet en ligne : glisser de gauche (fermé) à droite (ouvert).
// ======================================================================

class ShutterRow extends StatefulWidget {
  const ShutterRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.onStep,
    this.busy = false,
    this.accent = Hud.cyan,
    this.icon = Icons.roller_shades,
  });

  final double? value; // 0 fermé … 100 ouvert
  final String label;
  final ValueChanged<int> onChanged;

  /// Ouvrir (true) / fermer (false) d'un coup.
  final ValueChanged<bool>? onStep;
  final bool busy;
  final Color accent;
  final IconData icon;

  @override
  State<ShutterRow> createState() => _ShutterRowState();
}

class _ShutterRowState extends State<ShutterRow> {
  double? _drag;
  int _lastTick = -1;

  void _update(double dx, double width) {
    final v = (dx / width).clamp(0.0, 1.0) * 100;
    final snapped = (v / 5).round() * 5.0;
    final tick = (snapped / 10).floor();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    setState(() => _drag = snapped);
  }

  void _commit() {
    final v = _drag;
    setState(() => _drag = null);
    if (v != null) {
      HapticFeedback.mediumImpact();
      widget.onChanged(v.round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragging = _drag != null;
    final shown = (_drag ?? widget.value ?? 0) / 100;
    final color = dragging ? Hud.amber : widget.accent;
    final pct = dragging ? '${_drag!.round()} %' : (widget.value == null ? '—' : '${widget.value!.round()} %');
    final state = widget.value == null
        ? ''
        : widget.value! <= 0
            ? 'Fermé'
            : widget.value! >= 100
                ? 'Ouvert'
                : 'Entrouvert';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(widget.icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.label,
                overflow: TextOverflow.ellipsis, style: Hud.bodyText(size: 16, weight: FontWeight.w600)),
          ),
          if (widget.busy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
            ),
          if (!dragging && state.isNotEmpty)
            Text('$state  ', style: Hud.bodyText(size: 13, color: Hud.dim)),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: Hud.label(size: 13, color: color, spacing: 1),
            child: Text(pct),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _stepButton(Icons.keyboard_double_arrow_down_rounded, () => widget.onStep?.call(false)),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _update(d.localPosition.dx, c.maxWidth),
                onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, c.maxWidth),
                onHorizontalDragEnd: (_) => _commit(),
                onTapUp: (d) {
                  _update(d.localPosition.dx, c.maxWidth);
                  _commit();
                },
                child: SizedBox(
                  height: 34,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: shown),
                    duration: Duration(milliseconds: dragging ? 0 : 450),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => CustomPaint(painter: _RowPainter(v, color, dragging)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          _stepButton(Icons.keyboard_double_arrow_up_rounded, () => widget.onStep?.call(true)),
        ]),
      ]),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) => InkResponse(
        radius: 22,
        onTap: widget.busy
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accent.withValues(alpha: 0.08),
            border: Border.all(color: widget.accent.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 18, color: widget.accent),
        ),
      );
}

class _RowPainter extends CustomPainter {
  _RowPainter(this.open, this.color, this.dragging);
  final double open;
  final Color color;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.06));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: 0.22),
    );
    // Partie ouverte (lumière).
    final w = size.width * open;
    if (w > 0) {
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, size.height),
        Paint()
          ..shader = LinearGradient(
            colors: [color.withValues(alpha: 0.10), color.withValues(alpha: dragging ? 0.45 : 0.32)],
          ).createShader(Rect.fromLTWH(0, 0, w, size.height)),
      );
      // Lames du volet sur la partie fermée.
      final slat = Paint()..color = color.withValues(alpha: 0.10);
      for (double x = w + 4; x < size.width; x += 8) {
        canvas.drawRect(Rect.fromLTWH(x, 4, 3, size.height - 8), slat);
      }
      canvas.restore();
    } else {
      final slat = Paint()..color = color.withValues(alpha: 0.10);
      for (double x = 4; x < size.width - 4; x += 8) {
        canvas.drawRect(Rect.fromLTWH(x, 4, 3, size.height - 8), slat);
      }
    }
    // Curseur.
    final x = w.clamp(6.0, size.width - 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: size.height - 6),
          const Radius.circular(3)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_RowPainter o) => o.open != open || o.color != color || o.dragging != dragging;
}

// ======================================================================
// Apparition en douceur (fondu + glissement), décalée selon [index].
// ======================================================================

class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + 70 * index),
      curve: Interval((index * 0.08).clamp(0.0, 0.5), 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Transition entre pages : fondu, léger zoom et glissement.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: inCurve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(inCurve),
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(inCurve),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
            child: ScaleTransition(scale: Tween(begin: 1.0, end: 0.98).animate(outCurve), child: child),
          ),
        ),
      ),
    );
  }
}
