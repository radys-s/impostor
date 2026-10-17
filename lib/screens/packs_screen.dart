import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/word_pack.dart';
import '../ui/theme.dart';
import 'ai_screen.dart';
import 'pack_editor_screen.dart';

class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.gameSettings.packIds;

    void toggle(WordPack pack, bool on) {
      final ids = {...selected};
      on ? ids.add(pack.id) : ids.remove(pack.id);
      state.updateGameSettings(state.gameSettings.copyWith(packIds: ids));
    }

    Widget tile(WordPack pack) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Text(pack.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${pack.words.length} slov${pack.fromAi ? ' · AI' : ''}'),
              onTap: () => _open(context, PackEditorScreen(pack: pack)),
              trailing: Checkbox(
                value: selected.contains(pack.id),
                onChanged: pack.words.isEmpty ? null : (v) => toggle(pack, v ?? false),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Témata'),
        actions: [
          if (selected.isNotEmpty)
            TextButton(
              onPressed: () => state.updateGameSettings(state.gameSettings.copyWith(packIds: {})),
              child: const Text('Zrušit výběr'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('Nové téma'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              selected.isEmpty
                  ? 'Nic nevybráno = hraje se se všemi vestavěnými tématy.'
                  : 'Hraje se jen s vybranými tématy.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Vygeneruj téma s AI', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Napiš cokoliv, třeba „filmy od Pixaru“'),
                onTap: () => _open(context, const AiScreen()),
              ),
            ),
          ),
          if (state.customPacks.isNotEmpty) ...[
            const SectionLabel('Moje témata'),
            for (final p in state.customPacks) tile(p),
          ],
          const SectionLabel('Vestavěná'),
          for (final p in state.builtinPacks) tile(p),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _create(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Vytvořit ručně'),
              subtitle: const Text('Napíšeš si vlastní slova'),
              onTap: () {
                Navigator.pop(sheet);
                _open(context, const PackEditorScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Vygenerovat s AI'),
              subtitle: const Text('Zadáš téma, AI doplní slova'),
              onTap: () {
                Navigator.pop(sheet);
                _open(context, const AiScreen());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
