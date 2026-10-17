import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/word_pack.dart';
import '../store/store.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ai_screen.dart';
import 'pack_editor_screen.dart';
import 'store_screen.dart';

class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ctx = state.playContext;
    final scheme = Theme.of(context).colorScheme;
    final selected = state.gameSettings.packIds;
    final offered = state.contextPacks;
    final store = [for (final p in offered) if (p.fromStore) p];
    final builtin = [for (final p in offered) if (p.builtin) p];
    final aiOn = state.has(FeaturePlugin.ai);

    Widget tile(WordPack pack) {
      final on = selected.contains(pack.id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PartyTile(
          leading: EmojiBadge(pack.emoji, size: 44),
          title: pack.name,
          subtitle: '${pack.words.length} slov${pack.fromAi ? ' · AI' : ''}${pack.fromStore ? ' · obchod' : ''}',
          onTap: () => _open(context, PackEditorScreen(pack: pack)),
          trailing: _SelectDot(
            on: on,
            enabled: pack.words.isNotEmpty,
            onChanged: (v) {
              tick(state.appSettings.haptics);
              state.togglePack(pack.id, v);
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Témata'),
        actions: [
          if (state.hasManualSelection)
            TextButton(onPressed: state.clearPackSelection, child: const Text('Zrušit výběr')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => aiOn ? _create(context) : _open(context, const PackEditorScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nové téma'),
      ),
      body: AmbientBackground(
        child: PageBody(
          stagger: false,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                state.hasManualSelection
                    ? 'Hraje se jen s označenými tématy.'
                    : 'Nic neoznačeno = hraje se se všemi tématy pro ${ctx.label.toLowerCase()}.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            if (aiOn)
              PartyTile(
                highlight: true,
                gradient: ctx.gradient,
                leading: const EmojiBadge('✨', size: 44, gradient: LinearGradient(colors: [Colors.white24, Colors.white10])),
                title: 'Vygeneruj téma s AI',
                subtitle: 'Napiš cokoliv, třeba „filmy od Pixaru“',
                onTap: () => _open(context, const AiScreen()),
              )
            else
              PartyTile(
                leading: const EmojiBadge('🧩', size: 44),
                title: 'Víc témat v obchodě',
                subtitle: 'Balíčky slov a AI generátor zdarma',
                trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                onTap: () => _open(context, const StoreScreen()),
              ),
            if (state.customPacks.isNotEmpty) ...[
              const SectionLabel('Moje témata'),
              for (final p in state.customPacks) tile(p),
            ],
            if (store.isNotEmpty) ...[
              const SectionLabel('Z obchodu'),
              for (final p in store) tile(p),
            ],
            SectionLabel('Vestavěná · ${ctx.label}'),
            for (final p in builtin) tile(p),
            const SizedBox(height: 72),
          ],
        ),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PartyTile(
                leading: const EmojiBadge('✍️', size: 44),
                title: 'Vytvořit ručně',
                subtitle: 'Napíšeš si vlastní slova',
                onTap: () {
                  Navigator.pop(sheet);
                  _open(context, const PackEditorScreen());
                },
              ),
              const SizedBox(height: 10),
              PartyTile(
                leading: const EmojiBadge('✨', size: 44),
                title: 'Vygenerovat s AI',
                subtitle: 'Zadáš téma, AI doplní slova',
                onTap: () {
                  Navigator.pop(sheet);
                  _open(context, const AiScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round animated check used for pack selection.
class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.on, required this.enabled, required this.onChanged});

  final bool on;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = AppScope.of(context).playContext.gradient;
    return Semantics(
      checked: on,
      enabled: enabled,
      label: 'Hrát s tímto tématem',
      child: Pressable(
        onTap: enabled ? () => onChanged(!on) : null,
        scale: 0.85,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.pop,
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on ? g : null,
            border: on ? null : Border.all(color: scheme.outline, width: 2),
          ),
          child: AnimatedScale(
            scale: on ? 1 : 0,
            duration: Motion.quick,
            curve: Motion.pop,
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
