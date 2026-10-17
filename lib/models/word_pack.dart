import '../util/text.dart';

class WordEntry {
  const WordEntry({required this.word, this.hint = '', this.similar = ''});

  final String word;

  /// Vague hint shown to the impostor in hint mode.
  final String hint;

  /// Related but different word given to the impostor in undercover mode.
  final String similar;

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
        word: (json['word'] as String? ?? '').trim(),
        hint: (json['hint'] as String? ?? '').trim(),
        similar: (json['similar'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        if (hint.isNotEmpty) 'hint': hint,
        if (similar.isNotEmpty) 'similar': similar,
      };

  WordEntry copyWith({String? word, String? hint, String? similar}) => WordEntry(
        word: word ?? this.word,
        hint: hint ?? this.hint,
        similar: similar ?? this.similar,
      );
}

class WordPack {
  const WordPack({
    required this.id,
    required this.name,
    this.emoji = '🎲',
    required this.words,
    this.builtin = false,
    this.fromAi = false,
  });

  final String id;
  final String name;
  final String emoji;
  final List<WordEntry> words;
  final bool builtin;
  final bool fromAi;

  factory WordPack.fromJson(Map<String, dynamic> json, {bool builtin = false}) => WordPack(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Bez názvu',
        emoji: json['emoji'] as String? ?? '🎲',
        words: [
          for (final w in (json['words'] as List? ?? const []))
            if (w is Map<String, dynamic>) WordEntry.fromJson(w),
        ].where((w) => w.word.isNotEmpty).toList(),
        builtin: builtin,
        fromAi: json['fromAi'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'fromAi': fromAi,
        'words': [for (final w in words) w.toJson()],
      };

  WordPack copyWith({String? id, String? name, String? emoji, List<WordEntry>? words, bool? builtin, bool? fromAi}) =>
      WordPack(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        words: words ?? this.words,
        builtin: builtin ?? this.builtin,
        fromAi: fromAi ?? this.fromAi,
      );
}

/// Removes empty and duplicate words (case- and diacritics-insensitive).
List<WordEntry> dedupeWords(Iterable<WordEntry> words) {
  final seen = <String>{};
  final result = <WordEntry>[];
  for (final w in words) {
    final key = normalizeWord(w.word);
    if (key.isEmpty || !seen.add(key)) continue;
    result.add(w);
  }
  return result;
}
