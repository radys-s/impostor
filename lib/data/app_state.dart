import 'package:flutter/widgets.dart';

import '../logic/game_engine.dart';
import '../models/settings.dart';
import '../models/word_pack.dart';
import '../util/text.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage, this.builtinPacks)
      : players = List.of(_storage.loadPlayers()),
        gameSettings = _storage.loadGameSettings(),
        appSettings = _storage.loadAppSettings(),
        customPacks = List.of(_storage.loadCustomPacks()),
        scores = Map.of(_storage.loadScores()),
        _recent = List.of(_storage.loadRecent());

  final Storage _storage;
  final List<WordPack> builtinPacks;
  final GameEngine engine = GameEngine();

  List<String> players;
  GameSettings gameSettings;
  AppSettings appSettings;
  List<WordPack> customPacks;
  Map<String, int> scores;
  final List<String> _recent;

  static const minPlayers = 3;
  static const maxPlayers = 20;
  static const _recentLimit = 60;

  String get installId => _storage.installId();

  List<WordPack> get allPacks => [...customPacks, ...builtinPacks];

  WordPack? packById(String id) {
    for (final p in allPacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Packs chosen for the next game; all built-in packs when nothing valid is selected.
  List<WordPack> get selectedPacks {
    final chosen = [for (final id in gameSettings.packIds) ?packById(id)].where((p) => p.words.isNotEmpty).toList();
    return chosen.isEmpty ? builtinPacks : chosen;
  }

  // Players

  String? addPlayer(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Zadej jméno';
    if (players.length >= maxPlayers) return 'Maximálně $maxPlayers hráčů';
    if (players.any((p) => normalizeWord(p) == normalizeWord(clean))) return 'Tohle jméno už ve hře je';
    players = [...players, clean];
    _savePlayers();
    return null;
  }

  String? renamePlayer(int index, String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Zadej jméno';
    for (var i = 0; i < players.length; i++) {
      if (i != index && normalizeWord(players[i]) == normalizeWord(clean)) return 'Tohle jméno už ve hře je';
    }
    final old = players[index];
    players = [...players]..[index] = clean;
    if (scores.containsKey(old)) {
      scores = {...scores}..[clean] = scores[old]!;
      scores.remove(old);
      _storage.saveScores(scores);
    }
    _savePlayers();
    return null;
  }

  void removePlayer(int index) {
    players = [...players]..removeAt(index);
    _savePlayers();
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  void reorderPlayers(int oldIndex, int newIndex) {
    final list = [...players];
    list.insert(newIndex, list.removeAt(oldIndex));
    players = list;
    _savePlayers();
  }

  void _savePlayers() {
    _storage.savePlayers(players);
    notifyListeners();
  }

  // Settings

  void updateGameSettings(GameSettings s) {
    gameSettings = s;
    _storage.saveGameSettings(s);
    notifyListeners();
  }

  void updateAppSettings(AppSettings s) {
    appSettings = s;
    _storage.saveAppSettings(s);
    notifyListeners();
  }

  // Packs

  void savePack(WordPack pack) {
    final cleaned = pack.copyWith(words: dedupeWords(pack.words), builtin: false);
    final index = customPacks.indexWhere((p) => p.id == cleaned.id);
    customPacks = [...customPacks];
    if (index >= 0) {
      customPacks[index] = cleaned;
    } else {
      customPacks.insert(0, cleaned);
    }
    _storage.saveCustomPacks(customPacks);
    notifyListeners();
  }

  void deletePack(String id) {
    customPacks = [for (final p in customPacks) if (p.id != id) p];
    if (gameSettings.packIds.contains(id)) {
      updateGameSettings(gameSettings.copyWith(packIds: {...gameSettings.packIds}..remove(id)));
    }
    _storage.saveCustomPacks(customPacks);
    notifyListeners();
  }

  String newPackId() => 'vlastni-${DateTime.now().microsecondsSinceEpoch}';

  // Rounds and scores

  Round startRound() {
    final round = engine.createRound(
      players: players,
      pool: engine.buildPool(selectedPacks),
      settings: gameSettings.clampedFor(players.length),
      recent: _recent.toSet(),
    );
    _recent.add(normalizeWord(round.entry.word));
    if (_recent.length > _recentLimit) _recent.removeRange(0, _recent.length - _recentLimit);
    _storage.saveRecent(_recent);
    return round;
  }

  void addPoints(Map<String, int> points) {
    scores = {...scores};
    points.forEach((player, value) => scores[player] = (scores[player] ?? 0) + value);
    _storage.saveScores(scores);
    notifyListeners();
  }

  void resetScores() {
    scores = {};
    _storage.saveScores(scores);
    notifyListeners();
  }
}

/// Exposes [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
