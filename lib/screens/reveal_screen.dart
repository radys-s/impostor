import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'round_screen.dart';

/// Pass-the-phone screen: each player privately flips their card.
class RevealScreen extends StatefulWidget {
  const RevealScreen({super.key, required this.round});

  final Round round;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  int _index = 0;
  bool _revealed = false;
  bool _seen = false;

  PlayerRole get _role => widget.round.roles[_index];
  bool get _last => _index == widget.round.roles.length - 1;

  void _flip() {
    tick(AppScope.read(context).appSettings.haptics);
    setState(() {
      _revealed = !_revealed;
      if (_revealed) _seen = true;
    });
  }

  void _next() {
    if (_last) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoundScreen(round: widget.round)));
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
      _seen = false;
    });
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukončit kolo?'),
        content: const Text('Rozdané role se zahodí.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Pokračovat')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ukončit')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.round.roles.length;
    final progress = (_index + (_seen ? 1 : 0)) / total;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Karta ${_index + 1} z $total'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Ukončit kolo',
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: AmbientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _GradientProgress(value: progress),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.quick),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey('$_index-$_revealed'),
                      children: [
                        Text(
                          _revealed ? _role.player : 'Předej telefon',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _revealed ? 'Zapamatuj si to' : _role.player,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _revealed ? 'Skrýt kartu' : 'Ukázat kartu',
                      child: Pressable(
                        onTap: _flip,
                        scale: 0.98,
                        child: FlipCard(
                          key: ValueKey(_index),
                          flipped: _revealed,
                          front: _CardFront(player: _role.player),
                          back: _CardBack(role: _role, packName: widget.round.packName),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.quick),
                    child: _seen && !_revealed
                        ? GradientButton(
                            key: const ValueKey('next'),
                            icon: _last ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                            onPressed: _next,
                            label: _last ? 'Všichni viděli, jdeme hrát' : 'Další hráč',
                          )
                        : OutlinedButton(
                            key: ValueKey(_revealed),
                            onPressed: _flip,
                            child: Text(_revealed ? 'Skrýt kartu' : 'Ukázat kartu'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientProgress extends StatelessWidget {
  const _GradientProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 8,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: Motion.of(context, Motion.base),
        curve: Motion.ease,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppScope.of(context).playContext.gradient,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D flip between [front] and [back].
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.flipped, required this.front, required this.back});

  final bool flipped;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: Motion.of(context, Motion.base),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final angle = t * pi;
        final showBack = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(pi), child: back)
              : front,
        );
      },
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.player});
  final String player;

  @override
  Widget build(BuildContext context) {
    final ctx = AppScope.of(context).playContext;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: ctx.gradient,
        boxShadow: [BoxShadow(color: ctx.accent.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 14))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -40,
            child: Text(
              '?',
              style: TextStyle(fontSize: 240, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Klepni a podívej se',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Ostatní se nedívají!', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.role, required this.packName});
  final PlayerRole role;
  final String packName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final impostor = role.kind == RoleKind.impostor;
    final ctx = AppScope.of(context).playContext;
    final fg = impostor ? Colors.white : scheme.onSurface;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: impostor ? null : scheme.surfaceContainerHighest,
        gradient: impostor ? Party.impostor : null,
        borderRadius: BorderRadius.circular(32),
        border: impostor ? null : Border.all(color: ctx.accent.withValues(alpha: 0.6), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (impostor) ...[
            const Icon(Icons.theater_comedy_outlined, size: 64, color: Colors.white),
            const SizedBox(height: 12),
            const FittedBox(
              child: Text('IMPOSTOR',
                  style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            Text(
              role.hint != null ? 'Nápověda: ${role.hint}' : ctx.impostorLine,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ] else ...[
            Text('Tajné slovo', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 12),
            FittedBox(
              child: Text(role.cardText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg, fontSize: 44, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            // Undercover players must look exactly like civilians, so the category
            // line is shown to everyone who has a word.
            Text('Téma: $packName', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
    return impostor ? _Pulse(child: card) : card;
  }
}

/// Breathing red glow around the impostor card.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
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
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Party.red.withValues(alpha: 0.25 + 0.3 * _c.value),
              blurRadius: 24 + 24 * _c.value,
              spreadRadius: 2 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
