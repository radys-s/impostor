import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';
import '../models/word_pack.dart';

/// Thin JSON layer over shared_preferences.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static Future<Storage> open() async => Storage(await SharedPreferences.getInstance());

  static const _players = 'players';
  static const _gameSettings = 'gameSettings';
  static const _appSettings = 'appSettings';
  static const _customPacks = 'customPacks';
  static const _scores = 'scores';
  static const _recent = 'recentWords';
  static const _installId = 'installId';

  List<String> loadPlayers() => _prefs.getStringList(_players) ?? const [];
  Future<void> savePlayers(List<String> players) => _prefs.setStringList(_players, players);

  GameSettings loadGameSettings() =>
      _decode(_gameSettings, GameSettings.fromJson) ?? const GameSettings();
  Future<void> saveGameSettings(GameSettings s) => _prefs.setString(_gameSettings, jsonEncode(s.toJson()));

  AppSettings loadAppSettings() => _decode(_appSettings, AppSettings.fromJson) ?? const AppSettings();
  Future<void> saveAppSettings(AppSettings s) => _prefs.setString(_appSettings, jsonEncode(s.toJson()));

  List<WordPack> loadCustomPacks() {
    final raw = _prefs.getString(_customPacks);
    if (raw == null) return const [];
    try {
      return [
        for (final p in jsonDecode(raw) as List)
          if (p is Map<String, dynamic>) WordPack.fromJson(p),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomPacks(List<WordPack> packs) =>
      _prefs.setString(_customPacks, jsonEncode([for (final p in packs) p.toJson()]));

  Map<String, int> loadScores() {
    final raw = _prefs.getString(_scores);
    if (raw == null) return const {};
    try {
      return {for (final e in (jsonDecode(raw) as Map).entries) e.key as String: e.value as int};
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveScores(Map<String, int> scores) => _prefs.setString(_scores, jsonEncode(scores));

  List<String> loadRecent() => _prefs.getStringList(_recent) ?? const [];
  Future<void> saveRecent(List<String> recent) => _prefs.setStringList(_recent, recent);

  /// Random anonymous id, used only for the AI daily quota.
  String installId() {
    final existing = _prefs.getString(_installId);
    if (existing != null) return existing;
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
    _prefs.setString(_installId, id);
    return id;
  }

  T? _decode<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Loads the built-in packs listed in assets/packs/index.json.
Future<List<WordPack>> loadBuiltinPacks([AssetBundle? bundle]) async {
  final assets = bundle ?? rootBundle;
  try {
    final ids = (jsonDecode(await assets.loadString('assets/packs/index.json')) as List).cast<String>();
    final packs = <WordPack>[];
    for (final id in ids) {
      try {
        final json = jsonDecode(await assets.loadString('assets/packs/$id.json')) as Map<String, dynamic>;
        final pack = WordPack.fromJson(json, builtin: true);
        if (pack.words.isNotEmpty) packs.add(pack);
      } catch (_) {
        // Skip a broken pack, keep the rest playable.
      }
    }
    if (packs.isNotEmpty) return packs;
  } catch (_) {
    // Fall through to the embedded pack.
  }
  return [fallbackPack];
}

/// Always-available pack so the game works even if assets fail to load.
const fallbackPack = WordPack(
  id: 'zaklad',
  name: 'Základ',
  emoji: '⭐',
  builtin: true,
  words: [
    WordEntry(word: 'Pizza', hint: 'Itálie', similar: 'Lasagne'),
    WordEntry(word: 'Pes', hint: 'Mazlíček', similar: 'Vlk'),
    WordEntry(word: 'Kino', hint: 'Plátno', similar: 'Divadlo'),
    WordEntry(word: 'Pláž', hint: 'Dovolená', similar: 'Bazén'),
    WordEntry(word: 'Učitel', hint: 'Škola', similar: 'Ředitel'),
    WordEntry(word: 'Kolo', hint: 'Pedály', similar: 'Koloběžka'),
    WordEntry(word: 'Lednice', hint: 'Zima', similar: 'Mrazák'),
    WordEntry(word: 'Fotbal', hint: 'Míč', similar: 'Hokej'),
    WordEntry(word: 'Praha', hint: 'Most', similar: 'Brno'),
    WordEntry(word: 'Vánoce', hint: 'Dárky', similar: 'Velikonoce'),
  ],
);
