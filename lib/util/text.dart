const _from = 'áäčďéěëíňóöřšťúůüýžÁÄČĎÉĚËÍŇÓÖŘŠŤÚŮÜÝŽ';
const _to = 'aacdeeeinoorstuuuyzAACDEEEINOORSTUUUYZ';

/// Lowercase, strip Czech diacritics and collapse whitespace.
/// Used for duplicate detection and comparing guesses.
String normalizeWord(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().runes) {
    final char = String.fromCharCode(rune);
    final index = _from.indexOf(char);
    buffer.write(index >= 0 ? _to[index] : char);
  }
  return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Czech plural: 1 hráč, 2–4 hráči, 5+ hráčů.
String plural(int n, String one, String few, String many) {
  if (n == 1) return one;
  if (n >= 2 && n <= 4) return few;
  return many;
}
