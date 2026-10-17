import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/settings.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class GameOptionsScreen extends StatelessWidget {
  const GameOptionsScreen({super.key});

  static const timers = [0, 60, 120, 180, 300, 420, 600];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final playerCount = state.players.length < 3 ? 3 : state.players.length;
    final s = state.gameSettings.clampedFor(playerCount);
    final upper = playerCount - 1;
    void update(GameSettings settings) => state.updateGameSettings(settings);

    return Scaffold(
      appBar: AppBar(title: const Text('Možnosti hry')),
      body: AmbientBackground(
        child: PageBody(
        children: [
          const SectionLabel('Impostoři'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Náhodný počet'),
                  subtitle: const Text('Nikdo neví, kolik impostorů hraje'),
                  value: s.randomImpostors,
                  onChanged: upper < 2
                      ? null
                      : (v) => update(s.copyWith(impostorMin: 1, impostorMax: v ? (upper < 2 ? 1 : 2) : 1)),
                ),
                if (!s.randomImpostors)
                  _Stepper(
                    label: 'Počet impostorů',
                    value: s.impostorMin,
                    min: 1,
                    max: upper,
                    onChanged: (v) => update(s.copyWith(impostorMin: v, impostorMax: v)),
                  )
                else ...[
                  _Stepper(
                    label: 'Nejméně',
                    value: s.impostorMin,
                    min: 1,
                    max: s.impostorMax - 1,
                    onChanged: (v) => update(s.copyWith(impostorMin: v)),
                  ),
                  _Stepper(
                    label: 'Nejvíc',
                    value: s.impostorMax,
                    min: s.impostorMin + 1,
                    max: upper,
                    onChanged: (v) => update(s.copyWith(impostorMax: v)),
                  ),
                ],
              ],
            ),
          ),
          const SectionLabel('Varianty'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Nápověda pro impostora'),
                  subtitle: const Text('Impostor uvidí nenápadnou nápovědu nebo téma'),
                  value: s.hint,
                  onChanged: (v) => update(s.copyWith(hint: v)),
                ),
                SwitchListTile(
                  title: const Text('Undercover'),
                  subtitle: const Text('Impostor dostane podobné slovo a neví, že je impostor'),
                  value: s.undercover,
                  onChanged: (v) => update(s.copyWith(undercover: v)),
                ),
                SwitchListTile(
                  title: const Text('Chaos'),
                  subtitle: const Text('Občas není impostor nikdo, nebo jsou to všichni'),
                  value: s.chaos,
                  onChanged: (v) => update(s.copyWith(chaos: v)),
                ),
              ],
            ),
          ),
          const SectionLabel('Časovač diskuze'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in timers)
                ChoiceChip(
                  label: Text(t == 0 ? 'Vypnuto' : '${t ~/ 60} min'),
                  selected: s.timerSeconds == t,
                  onSelected: (_) => update(s.copyWith(timerSeconds: t)),
                ),
            ],
          ),
          if (state.players.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Limity počtu impostorů se upraví podle počtu hráčů.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 44,
            child: AnimatedSwitcher(
              duration: Motion.quick,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
