import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/text.dart';
import 'context_screen.dart';
import 'game_options_screen.dart';
import 'packs_screen.dart';
import 'players_screen.dart';
import 'reveal_screen.dart';
import 'scores_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tips = [
    'Nápověda nemá být moc jasná, jinak impostor slovo uhodne.',
    'Impostore, poslouchej ostatní a navazuj na jejich slova.',
    'Zkuste undercover: impostor ani neví, že je impostor.',
    'Chaos občas rozdá impostora všem. Nebo nikomu.',
    'Vlastní téma vytvoříš v sekci Témata za pár vteřin.',
    'Časovač drží diskuzi v tempu. Zapneš ho v Možnostech.',
  ];
  final _tip = _tips[Random().nextInt(_tips.length)];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ctx = state.playContext;
    final s = state.gameSettings.clampedFor(state.players.length);
    final packs = state.selectedPacks;
    final wordCount = packs.fold<int>(0, (sum, p) => sum + p.words.length);
    final missing = AppState.minPlayers - state.players.length;

    final modes = [
      if (s.hint) 'nápověda',
      if (s.undercover) 'undercover',
      if (s.chaos) 'chaos',
      if (s.timerSeconds > 0) 'časovač ${s.timerSeconds ~/ 60} min',
    ];
    final impostors = s.randomImpostors ? '${s.impostorMin}–${s.impostorMax}' : '${s.impostorMin}';

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GradientText(
                        'Impostor',
                        colors: [...ctx.colors, Party.red],
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    if (state.scoresOn)
                      IconButton(
                        tooltip: 'Skóre',
                        icon: const Icon(Icons.emoji_events_outlined),
                        onPressed: () => _push(context, const ScoresScreen()),
                      ),
                    IconButton(
                      tooltip: 'Obchod s rozšířeními',
                      icon: const Icon(Icons.extension_outlined),
                      onPressed: () => _push(context, const StoreScreen()),
                    ),
                    IconButton(
                      tooltip: 'Nastavení',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    FadeSlideIn(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ContextPill(
                          context_: ctx,
                          onTap: () => _push(context, const ContextScreen(startup: false)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 1,
                      child: PartyTile(
                        leading: const EmojiBadge('👥'),
                        title: state.players.isEmpty
                            ? 'Přidej hráče'
                            : '${state.players.length} ${plural(state.players.length, 'hráč', 'hráči', 'hráčů')}',
                        subtitle: state.players.isEmpty ? 'Stačí jména, pořadí určí předávání telefonu' : state.players.join(', '),
                        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        onTap: () => _push(context, const PlayersScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 2,
                      child: PartyTile(
                        leading: EmojiBadge(packs.length == 1 ? packs.first.emoji : '🃏'),
                        title: state.hasManualSelection ? packs.map((p) => p.name).join(', ') : 'Všechna témata · ${ctx.label}',
                        subtitle: '${packs.length} ${plural(packs.length, 'téma', 'témata', 'témat')} · $wordCount slov',
                        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        onTap: () => _push(context, const PacksScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 3,
                      child: PartyTile(
                        leading: const EmojiBadge('🎭'),
                        title: 'Impostoři: $impostors',
                        subtitle: modes.isEmpty ? 'Klasika · klepni a přidej varianty' : modes.join(' · '),
                        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        onTap: () => _push(context, const GameOptionsScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      index: 4,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_tip, style: TextStyle(color: scheme.onSurfaceVariant))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FadeSlideIn(
                  index: 5,
                  child: GradientButton(
                    icon: Icons.play_arrow_rounded,
                    label: missing <= 0
                        ? 'Rozdat karty'
                        : 'Přidej ještě $missing ${plural(missing, 'hráče', 'hráče', 'hráčů')}',
                    onPressed: missing <= 0 ? () => _start(context) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    final round = AppScope.read(context).startRound();
    Navigator.of(context).push(_route(RevealScreen(round: round)));
  }

  static void _push(BuildContext context, Widget page) => Navigator.of(context).push(_route(page));

  static Route<void> _route(Widget page) => MaterialPageRoute(builder: (_) => page);
}
