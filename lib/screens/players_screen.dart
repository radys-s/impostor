import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('Hráči (${state.players.length})')),
      body: SafeArea(
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
                  IconButton.filled(
                    onPressed: full ? null : _add,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                    tooltip: 'Přidat',
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
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text(name.characters.first.toUpperCase())),
                              title: Text(name),
                              onTap: () => _rename(i, name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Odebrat',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => state.removePlayer(i),
                                  ),
                                  ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
          child: Text(
            'Přidej aspoň 3 hráče.\nPořadí určuje, jak si budete předávat telefon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}
