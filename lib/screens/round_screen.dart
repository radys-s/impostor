import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'result_screen.dart';
import 'vote_screen.dart';

/// Clue-giving and discussion phase.
class RoundScreen extends StatefulWidget {
  const RoundScreen({super.key, required this.round});

  final Round round;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  Timer? _timer;
  late final int _total;
  late int _remaining;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _total = AppScope.read(context).gameSettings.timerSeconds;
    _remaining = _total;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    tick(AppScope.read(context).appSettings.haptics);
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remaining <= 0) {
      setState(() => _remaining = _total);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        setState(() => _running = false);
        buzz(AppScope.read(context).appSettings.haptics);
      }
    });
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukončit kolo?'),
        content: const Text('Vrátíte se na začátek, impostor zůstane tajemstvím.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hrát dál')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ukončit')),
        ],
      ),
    );
    if (leave == true && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop();
    }
  }

  /// Lets one player re-check their card privately.
  Future<void> _peek() async {
    final role = await showModalBottomSheet<PlayerRole>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Kdo zapomněl?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Ostatní se nedívají. Karta se ukáže jen tobě.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final r in widget.round.roles)
              ListTile(
                leading: LetterBadge(r.player.characters.first.toUpperCase(), size: 36),
                title: Text(r.player, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.visibility_rounded),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;
    final impostor = role.kind == RoleKind.impostor;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(impostor ? Icons.theater_comedy_rounded : Icons.key_rounded, size: 40),
        title: Text(impostor ? 'Jsi IMPOSTOR' : role.cardText, textAlign: TextAlign.center),
        content: Text(
          impostor
              ? (role.hint != null ? 'Nápověda: ${role.hint}' : 'Neznáš slovo. Blafuj dál.')
              : 'Téma: ${widget.round.packName}',
          textAlign: TextAlign.center,
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Skrýt'))],
      ),
    );
  }

  void _finish() {
    _timer?.cancel();
    final state = AppScope.read(context);
    final page = state.votingOn ? VoteScreen(round: widget.round) : ResultScreen(round: widget.round);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ctx = state.playContext;
    final round = widget.round;
    final hasTimer = _total > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kolo'),
          leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Ukončit kolo', onPressed: _leave),
          actions: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Někdo zapomněl slovo',
              onPressed: _peek,
            ),
          ],
        ),
        body: AmbientBackground(
          child: PageBody(
            bottom: GradientButton(
              onPressed: _finish,
              icon: state.votingOn ? Icons.how_to_vote_rounded : Icons.visibility_rounded,
              label: state.votingOn ? 'Hlasovat' : 'Odhalit impostora',
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: ctx.gradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: ctx.accent.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 12))],
                ),
                child: Column(
                  children: [
                    const Text('ZAČÍNÁ', style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      round.startingPlayer,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Každý řekne jedno slovo k tajnému slovu. Pak diskutujte a nahlas hlasujte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Phases(voting: state.votingOn),
              if (hasTimer) ...[
                const SizedBox(height: 16),
                Center(
                  child: _TimerRing(
                    total: _total,
                    remaining: _remaining,
                    running: _running,
                    onTap: _toggleTimer,
                  ),
                ),
              ],
              const SectionLabel('Pořadí'),
              Card(
                child: Column(
                  children: [
                    for (final (i, seat) in round.order.indexed)
                      ListTile(
                        dense: true,
                        leading: LetterBadge('${i + 1}', size: 30),
                        title: Text(round.roles[seat].player, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular countdown painted with the context gradient.
class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.total, required this.remaining, required this.running, required this.onTap});

  final int total;
  final int remaining;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = AppScope.of(context).playContext;
    final urgent = remaining <= 10 && remaining > 0;
    final minutes = (remaining ~/ 60).toString();
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final colors = urgent ? const [Party.red, Party.orange] : ctx.colors;
    return Semantics(
      button: true,
      label: 'Časovač $minutes:$seconds',
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          height: 220,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : remaining / total),
            duration: Motion.of(context, const Duration(milliseconds: 950)),
            curve: Curves.linear,
            builder: (context, v, _) => CustomPaint(
              painter: _RingPainter(value: v, colors: colors, track: scheme.surfaceContainerHighest),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$minutes:$seconds',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: urgent ? Party.red : null,
                          ),
                    ),
                    Text(
                      remaining <= 0 ? 'Čas! Klepni znovu' : (running ? 'Klepni pro pauzu' : 'Klepni a spusť'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.colors, required this.track});

  final double value;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(arc, 0, 2 * pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      arc,
      -pi / 2,
      2 * pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [colors.first, colors.last, colors.first],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.colors != colors || old.track != track;
}

/// What happens in this round, as three connected steps.
class _Phases extends StatelessWidget {
  const _Phases({required this.voting});

  final bool voting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      (Icons.record_voice_over_rounded, 'Slova'),
      (Icons.forum_rounded, 'Diskuze'),
      (voting ? Icons.how_to_vote_rounded : Icons.back_hand_rounded, 'Hlasování'),
    ];
    return Row(
      children: [
        for (final (i, (icon, label)) in steps.indexed) ...[
          if (i > 0)
            Expanded(
              child: Container(height: 2, margin: const EdgeInsets.only(bottom: 22), color: scheme.outlineVariant),
            ),
          Column(
            children: [
              IconBadge(icon, size: 40),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ],
    );
  }
}
