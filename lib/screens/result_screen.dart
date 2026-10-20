import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/text.dart';
import 'reveal_screen.dart';

/// The reveal. Without [votes] the group voted out loud.
/// Points are only asked for and shown when the scores plugin is installed.
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
  int _confetti = 0;

  Round get _round => widget.round;
  bool get _inApp => widget.votes != null;
  bool get _allImpostors => _round.impostors.length == _round.roles.length;

  bool get _caughtImpostor {
    final v = _vote;
    if (v == null || v.accused == null || v.tie || _allImpostors) return false;
    return _round.impostors.any((r) => r.player == v.accused);
  }

  @override
  void initState() {
    super.initState();
    // Verbal mode: the round screen's "Odhalit impostora" already was the reveal tap.
    if (!_inApp) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _reveal() : null);
  }

  void _reveal() {
    final state = AppScope.read(context);
    buzz(state.appSettings.haptics);
    setState(() {
      _revealed = true;
      _confetti++;
      if (_inApp && _caughtImpostor) {
        _stage = _Stage.guess;
      } else if (!_inApp && (!state.scoresOn || _allImpostors)) {
        // Assistant mode: nobody is judged, the app only reveals.
        _stage = _Stage.done;
      }
    });
    if (_inApp && !_caughtImpostor) _finish(decideWinner(_round, _vote!));
  }

  void _finish(Winner? winner) {
    setState(() {
      _winner = winner;
      _stage = _Stage.done;
      if (winner == Winner.civilians) _confetti++;
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

    return PopScope(
      canPop: _stage == _Stage.done || !_revealed,
      child: Scaffold(
        appBar: AppBar(title: const Text('Výsledek')),
        body: Stack(
          children: [
            AmbientBackground(
              colors: _revealed && _round.impostors.isNotEmpty ? const [Party.red, Party.pink, Party.orange] : null,
              child: PageBody(
                stagger: false,
                bottom: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.quick),
                  child: KeyedSubtree(key: ValueKey('$_revealed-$_stage'), child: _bottom(context, state)),
                ),
                children: [
                  if (_vote != null) FadeSlideIn(child: _VoteSummary(vote: _vote, round: _round)),
                  if (!_revealed && _inApp)
                    FadeSlideIn(
                      index: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            const _Wobble(child: IconBadge(Icons.person_search_rounded, size: 96)),
                            const SizedBox(height: 16),
                            Text(
                              'Hlasy jsou sečtené. Kdo to byl?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    _PopIn(child: _RevealCard(round: _round)),
                    if (_stage == _Stage.guess) ...[
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        index: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              '${_vote!.accused} je odhalen! Poslední šance: ať řekne nahlas, jaké je tajné slovo.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_stage == _Stage.done && _winner != null) ...[
                      const SizedBox(height: 16),
                      _PopIn(child: _WinnerBanner(winner: _winner!, round: _round, points: state.scoresOn)),
                    ],
                    if (_stage == _Stage.done && state.scoresOn && state.scores.isNotEmpty) ...[
                      const SectionLabel('Skóre'),
                      _ScoreList(scores: state.scores, players: state.players),
                    ],
                  ],
                ],
              ),
            ),
            if (_confetti > 0) Positioned.fill(child: ConfettiBurst(key: ValueKey(_confetti))),
          ],
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context, AppState state) {
    if (!_revealed) {
      if (!_inApp) return const SizedBox(height: 60);
      return GradientButton(
        onPressed: _reveal,
        icon: Icons.visibility_rounded,
        label: 'Odhalit',
        gradient: Party.impostor,
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
    if (_stage == _Stage.verdict) {
      // Only reached with the scores plugin in verbal mode.
      final noImpostor = _round.impostors.isEmpty;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Kdo bere body?', style: Theme.of(context).textTheme.titleMedium),
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
          child: GradientButton(onPressed: _nextRound, icon: Icons.replay_rounded, label: 'Další kolo'),
        ),
      ],
    );
  }
}

/// Scale-up entrance with a slight overshoot.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.reduced(context) ? 1 : 0.0, end: 1),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.pop,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
    );
  }
}

/// Gentle side-to-side wobble for the suspense emoji.
class _Wobble extends StatefulWidget {
  const _Wobble({required this.child});
  final Widget child;

  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Transform.rotate(
          angle: (Curves.easeInOut.transform(_c.value) - 0.5) * 0.25,
          child: child,
        ),
      );
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.round});
  final Round round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = AppScope.of(context).playContext;
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

    return Container(
      decoration: BoxDecoration(
        gradient: impostors.isEmpty ? ctx.gradient : Party.impostor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (impostors.isEmpty ? ctx.accent : Party.red).withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          if (impostors.isNotEmpty && round.chaos == null) ...[
            const SizedBox(height: 8),
            Text(
              impostors.map((r) => r.player).join(', '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Text('Tajné slovo', style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(round.entry.word, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                if (undercover)
                  Text('Undercover měl: ${round.entry.similar}', style: TextStyle(color: scheme.onSurfaceVariant)),
                Text('Téma: ${round.packName}', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final entries = vote.tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final (i, e) in entries.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key ?? 'Nikdo', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${e.value} ${plural(e.value, 'hlas', 'hlasy', 'hlasů')}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total == 0 ? 0 : e.value / total),
                      duration: Motion.of(context, Motion.slow + Motion.stagger * i),
                      curve: Motion.ease,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: i == 0 ? Party.red : scheme.primary,
                        ),
                      ),
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

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.winner, required this.round, required this.points});
  final Winner winner;
  final Round round;
  final bool points;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (round.impostors.length == round.roles.length) {
      text = 'Tohle kolo se nepočítá 😄';
    } else if (round.impostors.isEmpty) {
      text = winner == Winner.civilians
          ? 'Prokoukli jste to!${points ? ' +1 bod všem' : ''}'
          : 'Nachytali jste se.';
    } else if (winner == Winner.civilians) {
      text = 'Vyhráli hráči!${points ? ' +1 bod' : ''}';
    } else {
      text = '${plural(round.impostors.length, 'Vyhrál impostor', 'Vyhráli impostoři', 'Vyhráli impostoři')}!'
          '${points ? ' +2 body' : ''}';
    }
    final g = winner == Winner.civilians
        ? const LinearGradient(colors: [Party.green, Party.yellow])
        : const LinearGradient(colors: [Party.pink, Party.violet]);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(24)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
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
            ListTile(
              dense: true,
              title: Text(p),
              trailing: Text('${scores[p] ?? 0}', style: Theme.of(context).textTheme.titleMedium),
            ),
        ],
      ),
    );
  }
}
