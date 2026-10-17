import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/theme.dart';
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
  late int _remaining;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _remaining = AppScope.read(context).gameSettings.timerSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remaining <= 0) return;
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

  void _finish() {
    _timer?.cancel();
    final state = AppScope.read(context);
    final page = state.appSettings.inAppVoting
        ? VoteScreen(round: widget.round)
        : ResultScreen(round: widget.round);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final round = widget.round;
    final hasTimer = state.gameSettings.timerSeconds > 0;
    final minutes = (_remaining ~/ 60).toString();
    final seconds = (_remaining % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kolo'), automaticallyImplyLeading: false),
        body: PageBody(
          bottom: FilledButton.icon(
            onPressed: _finish,
            icon: Icon(state.appSettings.inAppVoting ? Icons.how_to_vote_outlined : Icons.visibility_outlined),
            label: Text(state.appSettings.inAppVoting ? 'Hlasovat' : 'Odhalit impostora'),
          ),
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Začíná', style: TextStyle(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      round.startingPlayer,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Každý řekne jedno slovo, které souvisí s tajným slovem. Pak diskutujte a hlasujte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
            if (hasTimer) ...[
              const SizedBox(height: 16),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _toggleTimer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Text(
                          '$minutes:$seconds',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: _remaining <= 10 && _remaining > 0 ? impostorColor : null,
                              ),
                        ),
                        Text(
                          _remaining <= 0 ? 'Čas vypršel' : (_running ? 'Klepni pro pauzu' : 'Klepni a spusť časovač'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
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
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
                      title: Text(round.roles[seat].player),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
