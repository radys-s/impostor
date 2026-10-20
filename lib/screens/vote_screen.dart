import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'result_screen.dart';

/// Secret in-app voting (plugin): the phone goes around once more.
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
        body: AmbientBackground(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.base),
            child: !_ready
                ? PageBody(
                    key: ValueKey('pass-$_index'),
                    bottom: GradientButton(
                      onPressed: () => setState(() => _ready = true),
                      icon: Icons.lock_open_rounded,
                      label: 'Jsem to já, hlasovat',
                    ),
                    children: [
                      const SizedBox(height: 72),
                      const Center(child: IconBadge(Icons.how_to_vote_rounded, size: 96)),
                      const SizedBox(height: 24),
                      Text('Předej telefon', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text(_voter, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text('Hlasuj tajně.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  )
                : PageBody(
                    key: ValueKey('vote-$_index'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                        child: Text('$_voter, kdo je podle tebe impostor?', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      for (final (i, name) in others.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PartyTile(
                            leading: LetterBadge(name.characters.first.toUpperCase(), size: 40),
                            title: name,
                            trailing: Icon(Icons.how_to_vote_outlined, color: scheme.onSurfaceVariant),
                            onTap: () => _vote(name),
                            key: ValueKey('vote-$i-$name'),
                          ),
                        ),
                      if (allowNobody)
                        PartyTile(
                          leading: const IconBadge(Icons.block_rounded, size: 40),
                          title: 'Žádný impostor tu není',
                          onTap: () => _vote(null),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
