import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/theme.dart';
import '../util/text.dart';

class ScoresScreen extends StatelessWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final names = {...state.players, ...state.scores.keys}.toList()
      ..sort((a, b) => (state.scores[b] ?? 0).compareTo(state.scores[a] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skóre'),
        actions: [
          if (state.scores.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vynulovat skóre?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vynulovat')),
                    ],
                  ),
                );
                if (ok == true) state.resetScores();
              },
              child: const Text('Vynulovat'),
            ),
        ],
      ),
      body: PageBody(
        children: [
          if (names.isEmpty || state.scores.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Zatím žádné body.\nHráči dostanou +1 za odhalení impostora, impostor +2 za výhru.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (i, name) in names.indexed)
                    ListTile(
                      leading: CircleAvatar(child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}')),
                      title: Text(name),
                      trailing: Text(
                        '${state.scores[name] ?? 0} ${plural(state.scores[name] ?? 0, 'bod', 'body', 'bodů')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
