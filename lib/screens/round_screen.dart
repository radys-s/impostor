import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/events.dart';
import '../logic/game_engine.dart';
import '../models/play_context.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/roles.dart';
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
    _total = widget.round.eventTimer ?? AppScope.read(context).gameSettings.timerSeconds;
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
    final ctx = AppScope.read(context).playContext;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(role.icon, size: 40),
        title: Text(
          [if (role.badge != null) role.badge!, if (role.knowsWord) role.cardText].join(' · '),
          textAlign: TextAlign.center,
        ),
        content: Text(role.secretLines(ctx, widget.round.packName).join('\n'), textAlign: TextAlign.center),
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
              if (round.event != null) ...[
                const SizedBox(height: 16),
                _EventCard(event: round.event!, letter: round.eventLetter),
              ],
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

/// The round's twist: drops in with a bounce and keeps a soft glow.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.letter});

  final RoundEvent event;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final adult = !event.audiences.contains(Audience.family) && !event.audiences.contains(Audience.friends);
    final colors = adult ? const [Party.pink, Party.violet] : const [Party.yellow, Party.orange];
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.first.withValues(alpha: 0.7), width: 2),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(EventIcons.of(event.icon), gradient: LinearGradient(colors: colors), size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EVENT KOLA',
                  style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: colors.first),
                ),
                const SizedBox(height: 2),
                Text(event.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(event.textWith(letter), style: TextStyle(height: 1.35, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: 'Event kola: ${event.title}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0.0, end: 1),
        duration: Motion.of(context, Motion.cinematic),
        curve: Motion.pop,
        child: card,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -24 * (1 - t)),
            child: Transform.rotate(angle: 0.04 * (1 - t), child: child),
          ),
        ),
      ),
    );
  }
}
