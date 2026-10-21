import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/motion.dart';
import '../ui/roles.dart';
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

  /// Everyone has seen their card; waiting to start the round.
  bool _done = false;

  /// Swallows a quick second tap right after hiding, so the previous player
  /// cannot accidentally open the next player's card.
  bool _locked = false;
  Timer? _unlock;

  @override
  void dispose() {
    _unlock?.cancel();
    super.dispose();
  }

  PlayerRole get _role => widget.round.roles[_index];
  bool get _last => _index == widget.round.roles.length - 1;
  String? get _nextPlayer => _last ? null : widget.round.roles[_index + 1].player;

  void _tapCard() {
    if (_done) return _start();
    if (_locked) return;
    tick(AppScope.read(context).appSettings.haptics);
    if (!_revealed) {
      setState(() => _revealed = true);
      return;
    }
    // Hide and hand over in one step.
    _locked = true;
    _unlock = Timer(const Duration(milliseconds: 700), () => _locked = false);
    setState(() {
      _revealed = false;
      if (_last) {
        _done = true;
      } else {
        _index++;
      }
    });
  }

  bool _starting = false;

  void _start() {
    if (_starting) return;
    _starting = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoundScreen(round: widget.round)));
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
    final progress = _done ? 1.0 : (_index + (_revealed ? 1 : 0)) / total;
    final String over;
    final String headline;
    if (_done) {
      over = 'Hotovo';
      headline = 'Všichni mají kartu';
    } else if (_revealed) {
      over = _role.player;
      headline = 'Zapamatuj si to';
    } else {
      over = _index == 0 ? 'Začíná' : 'Předej telefon';
      headline = _role.player;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_done ? 'Karty rozdané' : 'Karta ${_index + 1} z $total'),
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
                  SizedBox(
                    height: 76,
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.base),
                      // Fade-through: the old line is gone before the new one appears.
                      switchInCurve: const Interval(0.5, 1, curve: Motion.ease),
                      switchOutCurve: const Interval(0.5, 1),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey('$_index-$_revealed-$_done'),
                        children: [
                          Text(
                            over,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            headline,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _done ? 'Začít kolo' : (_revealed ? 'Skrýt kartu a předat dál' : 'Ukázat kartu'),
                      excludeSemantics: true,
                      child: Pressable(
                        onTap: _tapCard,
                        scale: 0.98,
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.base),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
                          ),
                          child: _done
                              ? const _CardDone(key: ValueKey('done'))
                              : FlipCard(
                                  key: ValueKey(_index),
                                  flipped: _revealed,
                                  front: _CardFront(first: _index == 0),
                                  back: _CardBack(
                                    role: _role,
                                    packName: widget.round.packName,
                                    nextPlayer: _nextPlayer,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    icon: _done
                        ? Icons.play_arrow_rounded
                        : (_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: _tapCard,
                    label: _done
                        ? 'Začít kolo'
                        : (_revealed ? (_last ? 'Mám to, skrýt' : 'Mám to, skrýt a předat') : 'Ukázat kartu'),
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
  const _CardFront({required this.first});

  /// The first player gets a slightly longer explanation.
  final bool first;

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
                const TapHint(),
                const SizedBox(height: 20),
                const Text(
                  'Klepni na kartu',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    first
                        ? 'Ostatní se nedívají. Uvidíš tajné slovo, nebo zjistíš, že jsi impostor.'
                        : 'Ostatní se nedívají!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.role, required this.packName, this.nextPlayer});
  final PlayerRole role;
  final String packName;
  final String? nextPlayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = AppScope.of(context).playContext;
    final special = role.gradient;
    final impostor = role.kind == RoleKind.impostor;
    final fg = special != null ? Colors.white : scheme.onSurface;
    final sub = special != null ? Colors.white.withValues(alpha: 0.92) : scheme.onSurfaceVariant;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: special == null ? scheme.surfaceContainerHighest : null,
        gradient: special,
        borderRadius: BorderRadius.circular(32),
        border: special == null ? Border.all(color: ctx.accent.withValues(alpha: 0.6), width: 2) : null,
      ),
      // Scrolls instead of overflowing when a special card has many lines.
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (special != null) ...[
                Icon(role.icon, size: impostor ? 64 : 48, color: Colors.white),
                const SizedBox(height: 10),
                FittedBox(
                  child: Text(
                    role.badge!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: impostor ? 44 : 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ] else
                Text('Tajné slovo', style: TextStyle(color: sub, fontSize: 16)),
              if (role.knowsWord) ...[
                SizedBox(height: special != null ? 6 : 12),
                FittedBox(
                  child: Text(
                    role.cardText,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fg, fontSize: special != null ? 36 : 44, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (final line in role.secretLines(ctx, packName))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: special != null ? Colors.white : sub,
                      fontSize: special != null ? 17 : 15,
                      height: 1.3,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: fg.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      nextPlayer == null ? 'Klepni a skryj kartu' : 'Klepni, skryj a podej: $nextPlayer',
                      style: TextStyle(color: fg.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return impostor ? _Pulse(child: card) : card;
  }
}

/// Shown after the last card: everybody knows their role.
class _CardDone extends StatelessWidget {
  const _CardDone({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = AppScope.of(context).playContext;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: ctx.gradient,
        boxShadow: [BoxShadow(color: ctx.accent.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 14))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 84, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Můžete začít',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Položte telefon doprostřed. Aplikace řekne, kdo začíná.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
            ),
          ),
        ],
      ),
    );
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
