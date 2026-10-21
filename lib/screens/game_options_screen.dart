import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/events.dart';
import '../models/presets.dart';
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
          const SectionLabel('Režim'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              for (final p in GamePreset.values)
                _PresetCard(
                  preset: p,
                  selected: p.matches(s, playerCount),
                  onTap: () {
                    tick(state.appSettings.haptics);
                    update(p.apply(s, playerCount));
                  },
                ),
            ],
          ),
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
          const SectionLabel('Speciální role'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.manage_search_rounded),
                  title: const Text('Detektiv'),
                  subtitle: const Text('Jeden hráč zná slovo i impostory. Musí je nenápadně prozradit.'),
                  value: s.detective,
                  onChanged: (v) => update(s.copyWith(detective: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sentiment_very_satisfied_rounded),
                  title: const Text('Šašek'),
                  subtitle: const Text('Zná slovo, ale vyhraje sám, když ho vyhlasujete. +3 body'),
                  value: s.jester,
                  onChanged: (v) => update(s.copyWith(jester: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.handshake_rounded),
                  title: const Text('Spolčení impostoři'),
                  subtitle: const Text('Víc impostorů o sobě ví a může se krýt'),
                  value: s.allies,
                  onChanged: (v) => update(s.copyWith(allies: v)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Speciální role se rozdají, jen když zbudou aspoň 2 obyčejní hráči.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SectionLabel('Eventy kola'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in EventRate.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: s.eventRate == r,
                  onSelected: (_) => update(s.copyWith(eventRate: r)),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              state.playContext.adult
                  ? 'Twist do kola: pantomima, šeptanda, svůdný hlas, hot seat, panák…'
                  : 'Twist do kola: pantomima, šeptanda, rychlovka, roboti…',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.selected, required this.onTap});

  final GamePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = AppScope.of(context).playContext;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.quick),
          curve: Motion.ease,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: selected ? ctx.gradient : null,
            color: selected ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant),
            boxShadow: selected
                ? [BoxShadow(color: ctx.accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(preset.icon, color: selected ? Colors.white : ctx.accent, size: 28),
              const Spacer(),
              Text(
                preset.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                preset.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: selected ? Colors.white.withValues(alpha: 0.9) : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
