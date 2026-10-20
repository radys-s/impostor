import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/play_context.dart';
import 'motion.dart';
import 'theme.dart';

/// Scaffold body with the ambient background, a scrolling list and an optional pinned bottom action.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.bottom, this.stagger = true});

  final List<Widget> children;
  final Widget? bottom;

  /// Fade the children in one after another (only on first build).
  final bool stagger;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                for (final (i, child) in children.indexed)
                  stagger ? FadeSlideIn(index: i, child: child) : child,
              ],
            ),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FadeSlideIn(index: 2, child: bottom!),
            ),
        ],
      ),
    );
  }
}

/// One-shot entrance: fade + slide up, delayed by [index] × stagger.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 18});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.base);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.ease);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    final delay = Motion.stagger * min(widget.index, 8);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, (1 - _t.value) * widget.offset), child: child),
      ),
    );
  }
}

/// Scales down slightly while pressed. Wrap any tappable.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.instant,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Primary call to action filled with the context gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.gradient});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final enabled = onPressed != null;
    final g = gradient ?? state.playContext.gradient;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: enabled
            ? () {
                tick(state.appSettings.haptics);
                onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: Motion.quick,
          height: 60,
          decoration: BoxDecoration(
            gradient: enabled ? g : null,
            color: enabled ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            boxShadow: enabled
                ? [BoxShadow(color: g.colors.first.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: enabled ? Colors.white : scheme.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? Colors.white : scheme.onSurfaceVariant,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text painted with a slowly drifting gradient.
class GradientText extends StatefulWidget {
  const GradientText(this.text, {super.key, required this.style, required this.colors, this.animate = true});

  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final bool animate;

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shift = _c.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [...widget.colors, widget.colors.first],
            begin: Alignment(-1 + shift, -0.3),
            end: Alignment(1 + shift, 0.3),
          ).createShader(rect),
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}

/// Soft drifting colour blobs behind the content. Low contrast, decorative only.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child, this.colors, this.intensity = 1});

  final Widget child;
  final List<Color>? colors;
  final double intensity;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = AppScope.of(context).playContext;
    final colors = widget.colors ?? [...ctx.colors, Party.red];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _BlobPainter(
                    t: _c.value,
                    colors: colors,
                    opacity: (dark ? 0.22 : 0.16) * widget.intensity,
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.t, required this.colors, required this.opacity});

  final double t;
  final List<Color> colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * pi;
    final blobs = [
      (Offset(size.width * (0.15 + 0.1 * sin(a)), size.height * (0.12 + 0.05 * cos(a))), size.width * 0.75),
      (Offset(size.width * (0.95 - 0.1 * cos(a)), size.height * (0.35 + 0.08 * sin(a))), size.width * 0.7),
      (Offset(size.width * (0.4 + 0.15 * cos(a)), size.height * (0.95 - 0.05 * sin(a))), size.width * 0.8),
    ];
    for (final (i, (center, radius)) in blobs.indexed) {
      final color = colors[i % colors.length];
      final paint = Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.colors != colors || old.opacity != opacity;
}

/// Card with a soft gradient wash and press animation.
class PartyTile extends StatelessWidget {
  const PartyTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.gradient,
    this.highlight = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Gradient? gradient;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = highlight ? Colors.white : scheme.onSurface;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlight ? null : scheme.surfaceContainerHigh,
          gradient: highlight ? gradient : null,
          borderRadius: BorderRadius.circular(24),
          border: highlight ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: highlight ? Colors.white.withValues(alpha: 0.85) : scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Rounded square with a gradient fill and a white line icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.gradient, this.size = 48});

  final IconData icon;
  final Gradient? gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppScope.of(context).playContext.gradient;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [BoxShadow(color: g.colors.first.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Small pill showing the current context; tap to change it.
class ContextPill extends StatelessWidget {
  const ContextPill({super.key, required this.context_, this.onTap});

  final PlayContext context_;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(gradient: context_.gradient, borderRadius: BorderRadius.circular(40)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(context_.icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(context_.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

/// One-shot confetti burst from the top centre.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 70});
  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _pieces = List.generate(widget.count, (_) {
      final angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 0.9;
      return _Piece(
        dx: cos(angle) * (0.4 + r.nextDouble() * 0.8),
        dy: sin(angle) * (0.6 + r.nextDouble() * 0.9),
        spin: (r.nextDouble() - 0.5) * 14,
        color: Party.confetti[r.nextInt(Party.confetti.length)],
        size: 6 + r.nextDouble() * 6,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({required this.dx, required this.dy, required this.spin, required this.color, required this.size});
  final double dx, dy, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.28);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in pieces) {
      final x = origin.dx + p.dx * size.width * 0.6 * t;
      final y = origin.dy + p.dy * size.height * 0.5 * t + size.height * 0.9 * t * t;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), const Radius.circular(2)),
        Paint()..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Same shape as [IconBadge] but with a short text (initial, rank, order).
class LetterBadge extends StatelessWidget {
  const LetterBadge(this.text, {super.key, this.gradient, this.size = 40});

  final String text;
  final Gradient? gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppScope.of(context).playContext.gradient;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.42),
      ),
    );
  }
}

/// Animated "tap here" cue: a finger icon that taps while rings ripple out.
/// Static under reduced motion.
class TapHint extends StatefulWidget {
  const TapHint({super.key, this.size = 84, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  State<TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<TapHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox(
        width: s * 1.6,
        height: s * 1.6,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Press happens in the first 30 %, ripple follows.
            final press = t < 0.15 ? t / 0.15 : (t < 0.3 ? 1 - (t - 0.15) / 0.15 : 0.0);
            final ripple = t < 0.15 ? 0.0 : ((t - 0.15) / 0.85).clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (ripple > 0)
                  Container(
                    width: s * (0.7 + 0.9 * ripple),
                    height: s * (0.7 + 0.9 * ripple),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color.withValues(alpha: 0.6 * (1 - ripple)), width: 2),
                    ),
                  ),
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.18)),
                ),
                Transform.translate(
                  offset: Offset(0, 4 * press),
                  child: Transform.scale(
                    scale: 1 - 0.1 * press,
                    child: Icon(Icons.touch_app_rounded, size: s * 0.55, color: widget.color),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
