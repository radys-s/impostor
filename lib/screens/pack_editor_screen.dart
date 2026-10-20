import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/word_pack.dart';
import '../store/store.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/text.dart';
import 'ai_screen.dart';

/// View a built-in pack, or create/edit a custom one.
class PackEditorScreen extends StatefulWidget {
  const PackEditorScreen({super.key, this.pack});

  /// null = new pack.
  final WordPack? pack;

  @override
  State<PackEditorScreen> createState() => _PackEditorScreenState();
}

class _PackEditorScreenState extends State<PackEditorScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.pack?.name ?? '');
  late String _emoji = widget.pack?.emoji ?? '🎲';
  late List<WordEntry> _words = List.of(widget.pack?.words ?? const []);
  late bool _fromAi = widget.pack?.fromAi ?? false;
  bool _dirty = false;

  bool get _readOnly => widget.pack?.readOnly ?? false;

  static const _emojis = PackIcons.editorChoices;

  @override
  void initState() {
    super.initState();
    // An unsaved copy of a built-in pack counts as a pending change.
    final pack = widget.pack;
    _dirty = pack != null && !pack.readOnly && !AppScope.read(context).customPacks.any((p) => p.id == pack.id);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  bool _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Pojmenuj téma');
      return false;
    }
    final words = dedupeWords(_words);
    if (words.length < 3) {
      showSnack(context, 'Přidej aspoň 3 slova');
      return false;
    }
    final state = AppScope.read(context);
    state.savePack(WordPack(
      id: widget.pack?.id ?? state.newPackId(),
      name: name,
      emoji: _emoji,
      words: words,
      fromAi: _fromAi,
      audience: widget.pack?.audience ?? state.playContext.defaultAudience,
    ));
    _dirty = false;
    return true;
  }

  Future<void> _editWord([int? index]) async {
    final result = await showDialog<WordEntry>(
      context: context,
      builder: (_) => _WordDialog(entry: index == null ? null : _words[index]),
    );
    if (result == null || result.word.isEmpty) return;
    final duplicate = _words.indexed.any((e) => e.$1 != index && normalizeWord(e.$2.word) == normalizeWord(result.word));
    if (duplicate) {
      if (mounted) showSnack(context, 'Slovo „${result.word}“ už v tématu je');
      return;
    }
    _changed(() => index == null ? _words.insert(0, result) : _words[index] = result);
  }

  Future<void> _fillWithAi() async {
    final topic = _name.text.trim();
    final added = await Navigator.of(context).push<List<WordEntry>>(
      MaterialPageRoute(builder: (_) => AiScreen(initialTopic: topic, existing: _words, returnWords: true)),
    );
    if (added == null || added.isEmpty) return;
    _changed(() {
      _words = dedupeWords([..._words, ...added]);
      _fromAi = true;
    });
    if (mounted) showSnack(context, 'Přidáno ${added.length} slov');
  }

  void _copy() {
    final pack = widget.pack!;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PackEditorScreen(
        pack: WordPack(
          id: AppScope.read(context).newPackId(),
          name: '${pack.name} (kopie)',
          emoji: pack.emoji,
          words: pack.words,
          audience: pack.audience,
        ),
      ),
    ));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat téma?'),
        content: Text('„${widget.pack!.name}“ se nenávratně smaže.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Smazat')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    AppScope.read(context).deletePack(widget.pack!.id);
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uložit změny?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Zahodit')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Uložit')),
        ],
      ),
    );
    if (result == 'save') return _save();
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    final exists = widget.pack != null && state.customPacks.any((p) => p.id == widget.pack!.id);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_readOnly ? widget.pack!.name : (widget.pack == null ? 'Nové téma' : 'Upravit téma')),
          actions: [
            if (_readOnly)
              TextButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('Upravit kopii'))
            else ...[
              if (exists) IconButton(tooltip: 'Smazat', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
              TextButton(
                onPressed: () {
                  if (_save()) Navigator.of(context).pop();
                },
                child: const Text('Uložit'),
              ),
            ],
          ],
        ),
        floatingActionButton: _readOnly
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _editWord(),
                icon: const Icon(Icons.add),
                label: const Text('Slovo'),
              ),
        body: AmbientBackground(
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!_readOnly) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Název tématu'),
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final e in _emojis)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Icon(PackIcons.of(e), size: 22, semanticLabel: 'Ikona ${PackIcons.editorChoices.indexOf(e) + 1}'),
                          showCheckmark: false,
                          selected: _emoji == e,
                          onSelected: (_) => _changed(() => _emoji = e),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.has(FeaturePlugin.ai)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _fillWithAi,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Doplnit slova pomocí AI'),
                ),
              ],
            ],
            SectionLabel('${_words.length} slov'),
            if (_words.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.has(FeaturePlugin.ai)
                      ? 'Zatím žádná slova. Přidej je ručně, nebo nech AI, ať je doplní.'
                      : 'Zatím žádná slova. Přidej je tlačítkem Slovo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final (i, w) in _words.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  child: ListTile(
                    title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: (w.hint.isEmpty && w.similar.isEmpty)
                        ? null
                        : Text([
                            if (w.hint.isNotEmpty) 'nápověda: ${w.hint}',
                            if (w.similar.isNotEmpty) 'podobné: ${w.similar}',
                          ].join(' · ')),
                    onTap: _readOnly ? null : () => _editWord(i),
                    trailing: _readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _changed(() => _words.removeAt(i)),
                          ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _WordDialog extends StatefulWidget {
  const _WordDialog({this.entry});
  final WordEntry? entry;

  @override
  State<_WordDialog> createState() => _WordDialogState();
}

class _WordDialogState extends State<_WordDialog> {
  late final _word = TextEditingController(text: widget.entry?.word ?? '');
  late final _hint = TextEditingController(text: widget.entry?.hint ?? '');
  late final _similar = TextEditingController(text: widget.entry?.similar ?? '');

  @override
  void dispose() {
    _word.dispose();
    _hint.dispose();
    _similar.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
        context,
        WordEntry(word: _word.text.trim(), hint: _hint.text.trim(), similar: _similar.text.trim()),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Nové slovo' : 'Upravit slovo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _word,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Tajné slovo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hint,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nápověda pro impostora (nepovinné)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _similar,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Podobné slovo pro undercover (nepovinné)'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
        FilledButton(onPressed: _submit, child: const Text('Hotovo')),
      ],
    );
  }
}
