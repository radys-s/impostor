import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/theme.dart';
import '../util/text.dart';
import 'reveal_screen.dart';

/// Reveal and scoring. Without [votes] the group voted out loud.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.round, this.votes});

  final Round round;
  final Map<String, String?>? votes;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

enum _Stage { verdict, guess, done }

class _ResultScreenState extends State<ResultScreen> {
  late final VoteOutcome? _vote = widget.votes == null ? null : tallyVotes(widget.votes!);
  bool _revealed = false;
  _Stage _stage = _Stage.verdict;
  Winner? _winner;
  bool _scored = false;

  Round get _round => widget.round;
  bool get _inApp => widget.votes != null;
  bool get _allImpostors => _round.impostors.length == _round.roles.length;

  bool get _caughtImpostor {
    final v = _vote;
    if (v == null || v.accused == null || v.tie || _allImpostors) return false;
    return _round.impostors.any((r) => r.player == v.accused);
  }

  void _reveal() {
    buzz(AppScope.read(context).appSettings.haptics);
    setState(() {
      _revealed = true;
      if (_inApp) {
        if (_caughtImpostor) {
          _stage = _Stage.guess;
        } else {
          _finish(decideWinner(_round, _vote!));
        }
      }
    });
  }

  void _finish(Winner? winner) {
    setState(() {
      _winner = winner;
      _stage = _Stage.done;
    });
    if (winner != null && !_scored) {
      _scored = true;
      AppScope.read(context).addPoints(roundPoints(_round, winner));
    }
  }

  void _nextRound() {
    final round = AppScope.read(context).startRound();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RevealScreen(round: round)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _stage == _Stage.done || !_revealed,
      child: Scaffold(
        appBar: AppBar(title: const Text('Výsledek')),
        body: PageBody(
          bottom: _bottom(context),
          children: [
            if (_vote != null) _VoteSummary(vote: _vote, round: _round),
            if (!_revealed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.help_outline, size: 72, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      _inApp ? 'Hlasy jsou sečtené.' : 'Máte hotovo? Ukažte, kdo to byl.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            else ...[
              const SizedBox(height: 8),
              _RevealCard(round: _round),
              if (_stage == _Stage.guess) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '${_vote!.accused} byl odhalen! Poslední šance: ať řekne nahlas, jaké je tajné slovo.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
              if (_stage == _Stage.done && _winner != null) ...[
                const SizedBox(height: 16),
                _WinnerBanner(winner: _winner!, round: _round),
              ],
              if (_stage == _Stage.done && state.scores.isNotEmpty) ...[
                const SectionLabel('Skóre'),
                _ScoreList(scores: state.scores, players: state.players),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    if (!_revealed) {
      return FilledButton.icon(
        onPressed: _reveal,
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Odhalit'),
      );
    }
    if (_stage == _Stage.guess) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _finish(decideWinner(_round, _vote!)),
              child: const Text('Neuhodl'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _finish(decideWinner(_round, _vote!, impostorGuessedWord: true)),
              child: const Text('Uhodl'),
            ),
          ),
        ],
      );
    }
    if (_stage == _Stage.verdict && !_inApp && !_allImpostors) {
      final noImpostor = _round.impostors.isEmpty;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Kdo vyhrál?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finish(Winner.civilians),
                  child: Text(noImpostor ? 'Prokoukli to' : 'Hráči'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finish(Winner.impostors),
                  child: Text(noImpostor ? 'Nachytali se' : plural(_round.impostors.length, 'Impostor', 'Impostoři', 'Impostoři')),
                ),
              ),
            ],
          ),
          TextButton(onPressed: () => _finish(null), child: const Text('Nepočítat')),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Domů')),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(onPressed: _nextRound, child: const Text('Další kolo')),
        ),
      ],
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.round});
  final Round round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final impostors = round.impostors;
    final String title;
    if (round.chaos == ChaosKind.nobody) {
      title = 'Chaos! Žádný impostor nebyl.';
    } else if (round.chaos == ChaosKind.everybody) {
      title = 'Chaos! Impostoři byli všichni.';
    } else {
      title = plural(impostors.length, 'Impostor', 'Impostoři', 'Impostoři');
    }
    final undercover = impostors.any((r) => r.kind == RoleKind.undercover);

    return Card(
      color: impostors.isEmpty ? scheme.secondaryContainer : impostorColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: impostors.isEmpty ? scheme.onSecondaryContainer : Colors.white,
                )),
            if (impostors.isNotEmpty && round.chaos == null) ...[
              const SizedBox(height: 8),
              Text(
                impostors.map((r) => r.player).join(', '),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text('Tajné slovo', style: TextStyle(color: scheme.onSurfaceVariant)),
                  Text(round.entry.word,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (undercover)
                    Text('Undercover měl: ${round.entry.similar}', style: TextStyle(color: scheme.onSurfaceVariant)),
                  Text('Téma: ${round.packName}', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteSummary extends StatelessWidget {
  const _VoteSummary({required this.vote, required this.round});
  final VoteOutcome vote;
  final Round round;

  @override
  Widget build(BuildContext context) {
    final entries = vote.tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final String headline;
    if (vote.tie) {
      headline = 'Remíza, nikdo nebyl vyloučen';
    } else if (vote.accused == null) {
      headline = 'Většina si myslí, že impostor není';
    } else {
      headline = 'Nejvíc hlasů: ${vote.accused}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key ?? 'Nikdo')),
                    Text('${e.value} ${plural(e.value, 'hlas', 'hlasy', 'hlasů')}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.winner, required this.round});
  final Winner winner;
  final Round round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (round.impostors.length == round.roles.length) {
      text = 'Tohle kolo se nepočítá 😄';
    } else if (round.impostors.isEmpty) {
      text = winner == Winner.civilians ? 'Prokoukli jste to! +1 bod všem' : 'Nachytali jste se. Bez bodů.';
    } else if (winner == Winner.civilians) {
      text = 'Vyhráli hráči! +1 bod';
    } else {
      text = '${plural(round.impostors.length, 'Vyhrál impostor', 'Vyhráli impostoři', 'Vyhráli impostoři')}! +2 body';
    }
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onTertiaryContainer,
              ),
        ),
      ),
    );
  }
}

class _ScoreList extends StatelessWidget {
  const _ScoreList({required this.scores, required this.players});
  final Map<String, int> scores;
  final List<String> players;

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return Card(
      child: Column(
        children: [
          for (final p in sorted)
            ListTile(dense: true, title: Text(p), trailing: Text('${scores[p] ?? 0}', style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}
