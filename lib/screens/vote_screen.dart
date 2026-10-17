import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/theme.dart';
import 'result_screen.dart';

/// Secret in-app voting: the phone goes around once more.
class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key, required this.round});

  final Round round;

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  final Map<String, String?> _votes = {};
  int _index = 0;
  bool _ready = false;

  static const _nobody = '\u0000nobody';

  String get _voter => widget.round.roles[_index].player;

  void _vote(String? target) {
    tick(AppScope.read(context).appSettings.haptics);
    _votes[_voter] = target;
    if (_index == widget.round.roles.length - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(round: widget.round, votes: Map.of(_votes))),
      );
      return;
    }
    setState(() {
      _index++;
      _ready = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final others = [for (final r in widget.round.roles) if (r.player != _voter) r.player];
    final allowNobody = state.gameSettings.chaos;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Hlasování ${_index + 1}/${widget.round.roles.length}'),
          automaticallyImplyLeading: false,
        ),
        body: !_ready
            ? PageBody(
                bottom: FilledButton(
                  onPressed: () => setState(() => _ready = true),
                  child: const Text('Jsem to já, hlasovat'),
                ),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.how_to_vote_outlined, size: 72, color: scheme.primary),
                  const SizedBox(height: 24),
                  Text('Předej telefon', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  Text(
                    _voter,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('Hlasuj tajně.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              )
            : PageBody(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                    child: Text(
                      '$_voter, kdo je podle tebe impostor?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final name in others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(onPressed: () => _vote(name), child: Text(name)),
                    ),
                  if (allowNobody) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const ValueKey(_nobody),
                      onPressed: () => _vote(null),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: const Text('Myslím, že tu žádný impostor není'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
