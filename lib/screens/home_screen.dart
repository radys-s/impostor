import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/theme.dart';
import '../util/text.dart';
import 'game_options_screen.dart';
import 'packs_screen.dart';
import 'players_screen.dart';
import 'reveal_screen.dart';
import 'scores_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = state.gameSettings.clampedFor(state.players.length);
    final packs = state.selectedPacks;
    final wordCount = packs.fold<int>(0, (sum, p) => sum + p.words.length);
    final canStart = state.players.length >= AppState.minPlayers;

    final modes = [
      if (s.hint) 'nápověda',
      if (s.undercover) 'undercover',
      if (s.chaos) 'chaos',
      if (s.timerSeconds > 0) 'časovač ${s.timerSeconds ~/ 60} min',
    ];
    final impostors = s.randomImpostors ? '${s.impostorMin}–${s.impostorMax}' : '${s.impostorMin}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostor'),
        actions: [
          IconButton(
            tooltip: 'Skóre',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => _push(context, const ScoresScreen()),
          ),
          IconButton(
            tooltip: 'Nastavení',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: PageBody(
        bottom: FilledButton.icon(
          onPressed: canStart ? () => _start(context) : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(canStart
              ? 'Začít hru'
              : 'Přidej ještě ${AppState.minPlayers - state.players.length} '
                  '${plural(AppState.minPlayers - state.players.length, 'hráče', 'hráče', 'hráčů')}'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Všichni znají tajné slovo. Až na impostora.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          _HomeTile(
            icon: Icons.group_outlined,
            title: '${state.players.length} ${plural(state.players.length, 'hráč', 'hráči', 'hráčů')}',
            subtitle: state.players.isEmpty ? 'Klepni a přidej hráče' : state.players.join(', '),
            onTap: () => _push(context, const PlayersScreen()),
          ),
          const SizedBox(height: 12),
          _HomeTile(
            icon: Icons.style_outlined,
            title: state.gameSettings.packIds.isEmpty ? 'Všechna témata' : packs.map((p) => p.name).join(', '),
            subtitle: '${packs.length} ${plural(packs.length, 'téma', 'témata', 'témat')} · $wordCount slov',
            onTap: () => _push(context, const PacksScreen()),
          ),
          const SizedBox(height: 12),
          _HomeTile(
            icon: Icons.tune,
            title: 'Impostoři: $impostors',
            subtitle: modes.isEmpty ? 'Klasická hra' : modes.join(' · '),
            onTap: () => _push(context, const GameOptionsScreen()),
          ),
        ],
      ),
    );
  }

  void _start(BuildContext context) {
    final round = AppScope.read(context).startRound();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevealScreen(round: round)));
  }

  static void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
