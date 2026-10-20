import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/text.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final error = AppScope.read(context).addPlayer(_controller.text);
    setState(() => _error = error);
    if (error == null) _controller.clear();
    _focus.requestFocus();
  }

  Future<void> _rename(int index, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přejmenovat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Uložit')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final error = AppScope.read(context).renamePlayer(index, name);
    if (error != null) showSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final full = state.players.length >= AppState.maxPlayers;
    final missing = AppState.minPlayers - state.players.length;
    return Scaffold(
      appBar: AppBar(title: Text('Hráči (${state.players.length})')),
      body: AmbientBackground(
        child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      enabled: !full,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: full ? 'Plno (max ${AppState.maxPlayers})' : 'Jméno hráče',
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Tooltip(
                      message: 'Přidat',
                      child: Pressable(
                        onTap: full ? null : _add,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: full ? null : state.playContext.gradient,
                            color: full ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.players.isEmpty
                  ? const _Empty()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: state.players.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: state.reorderPlayers,
                      itemBuilder: (context, i) {
                        final name = state.players[i];
                        return Padding(
                          key: ValueKey(name),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FadeSlideIn(
                            index: i,
                            child: Card(
                            child: ListTile(
                              leading: _Avatar(name: name, index: i),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              onTap: () => _rename(i, name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Odebrat',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () => state.removePlayer(i),
                                  ),
                                  ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                                ],
                              ),
                            ),
                          ),
                          ),
                        );
                      },
                    ),
            ),
            if (state.players.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Klepni na jméno a přejmenuj · táhni a změň pořadí',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GradientButton(
                      icon: missing > 0 ? Icons.person_add_alt_1_rounded : Icons.check_rounded,
                      label: missing > 0 ? 'Ještě $missing ${plural(missing, 'hráč', 'hráči', 'hráčů')}' : 'Hotovo',
                      onPressed: missing > 0 ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Initial on a party colour picked by position.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.index});

  final String name;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = Party.confetti[index % Party.confetti.length];
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.25)!]),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(Icons.group_add_rounded, size: 72),
              const SizedBox(height: 18),
              Text('Kdo hraje?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Napiš jméno nahoře a potvrď. Potřebujete aspoň 3 hráče.\nPořadí určuje, komu se předává telefon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      );
}
