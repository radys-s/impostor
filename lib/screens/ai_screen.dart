import 'package:flutter/material.dart';

import '../ai/ai_client.dart';
import '../data/app_state.dart';
import '../models/word_pack.dart';
import '../ui/theme.dart';
import '../util/text.dart';

/// Generates words for any topic via the free AI worker.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key, this.initialTopic = '', this.existing = const [], this.returnWords = false, this.client});

  final String initialTopic;

  /// Words already in the target pack; duplicates are filtered out.
  final List<WordEntry> existing;

  /// true = pop with the generated words instead of saving a new pack.
  final bool returnWords;
  final AiClient? client;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  late final _topic = TextEditingController(text: widget.initialTopic);
  late final AiClient _client = widget.client ?? AiClient();
  int _count = 30;
  bool _loading = false;
  String? _error;
  List<WordEntry>? _result;

  static const _ideas = [
    'Filmy od Pixaru',
    'Věci v kuchyni',
    'Česká jídla',
    'Pohádkové postavy',
    'Značky aut',
    'Harry Potter',
    'Věci na pláži',
    'Videohry',
  ];

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Napiš téma');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await _client.generate(topic: topic, count: _count, installId: AppScope.read(context).installId);
      final known = {for (final w in widget.existing) normalizeWord(w.word)};
      final fresh = [for (final w in words) if (!known.contains(normalizeWord(w.word))) w];
      if (!mounted) return;
      setState(() {
        _result = fresh;
        if (fresh.isEmpty) _error = 'AI vrátila jen slova, která už v tématu máš.';
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    final words = _result ?? const [];
    if (words.isEmpty) return;
    if (widget.returnWords) {
      Navigator.of(context).pop(words);
      return;
    }
    final state = AppScope.read(context);
    final name = _topic.text.trim();
    state.savePack(WordPack(
      id: state.newPackId(),
      name: name.characters.first.toUpperCase() + name.characters.skip(1).string,
      emoji: '✨',
      words: words,
      fromAi: true,
    ));
    showSnack(context, 'Téma uloženo do Moje témata');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('AI téma')),
      body: PageBody(
        bottom: result != null && result.isNotEmpty
            ? FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(widget.returnWords ? 'Přidat ${result.length} slov' : 'Uložit téma (${result.length} slov)'),
              )
            : FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'Generuji…' : 'Vygenerovat'),
              ),
        children: [
          TextField(
            controller: _topic,
            enabled: !_loading,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Téma', hintText: 'Třeba „zvířata v ZOO“'),
            onSubmitted: (_) => _generate(),
            onChanged: (_) {
              if (_result != null) setState(() => _result = null);
            },
          ),
          if (widget.initialTopic.isEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final idea in _ideas)
                  ActionChip(
                    label: Text(idea),
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _topic.text = idea;
                              _result = null;
                            }),
                  ),
              ],
            ),
          const SectionLabel('Počet slov'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 20, label: Text('20')),
              ButtonSegment(value: 30, label: Text('30')),
              ButtonSegment(value: 50, label: Text('50')),
            ],
            selected: {_count},
            onSelectionChanged: _loading ? null : (v) => setState(() => _count = v.first),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            ),
          if (result != null && result.isNotEmpty) ...[
            SectionLabel('Výsledek (${result.length})'),
            Row(
              children: [
                Expanded(
                  child: Text('Klepnutím na × slovo vyřadíš.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Znovu'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in result)
                  InputChip(
                    label: Text(w.word),
                    tooltip: w.hint.isEmpty && w.similar.isEmpty
                        ? null
                        : [if (w.hint.isNotEmpty) 'nápověda: ${w.hint}', if (w.similar.isNotEmpty) 'podobné: ${w.similar}']
                            .join(' · '),
                    onDeleted: () => setState(() => _result = [...result]..remove(w)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
