import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/theme.dart';
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_index + (_seen ? 1 : 0)) / total,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 24),
                Text(
                  _revealed ? _role.player : 'Předej telefon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  _revealed ? 'Zapamatuj si to' : _role.player,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: _flip,
                    child: FlipCard(
                      flipped: _revealed,
                      front: _CardFront(player: _role.player),
                      back: _CardBack(role: _role, packName: widget.round.packName),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _seen && !_revealed
                      ? FilledButton(
                          key: const ValueKey('next'),
                          onPressed: _next,
                          child: Text(_last ? 'Všichni viděli, jdeme hrát' : 'Další hráč'),
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
      duration: const Duration(milliseconds: 380),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 56, color: scheme.onPrimary),
          const SizedBox(height: 16),
          Text('Klepni a podívej se', style: TextStyle(color: scheme.onPrimary, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Ostatní se nedívají!', style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75))),
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
    final bg = impostor ? impostorColor : scheme.surfaceContainerHighest;
    final fg = impostor ? Colors.white : scheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: impostor ? null : Border.all(color: scheme.outlineVariant),
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
              role.hint != null ? 'Nápověda: ${role.hint}' : 'Neznáš slovo. Nenech se odhalit.',
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
  }
}
