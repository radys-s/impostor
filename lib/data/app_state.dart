import 'package:flutter/widgets.dart';

import '../logic/game_engine.dart';
import '../models/play_context.dart';
import '../models/settings.dart';
import '../models/word_pack.dart';
import '../store/store.dart';
import '../util/text.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage, this.builtinPacks)
      : players = List.of(_storage.loadPlayers()),
        gameSettings = _storage.loadGameSettings(),
        appSettings = _storage.loadAppSettings(),
        customPacks = List.of(_storage.loadCustomPacks()),
        storePacks = List.of(_storage.loadStorePacks()),
        features = _storage.loadFeatures(),
        playContext = _storage.loadContext() ?? PlayContext.friends,
        adultConfirmed = _storage.loadAdultConfirmed(),
        scores = Map.of(_storage.loadScores()),
        _recent = List.of(_storage.loadRecent());

  final Storage _storage;
  final List<WordPack> builtinPacks;
  final GameEngine engine = GameEngine();

  List<String> players;
  GameSettings gameSettings;
  AppSettings appSettings;
  List<WordPack> customPacks;
  List<WordPack> storePacks;
  Set<String> features;
  PlayContext playContext;
  bool adultConfirmed;
  Map<String, int> scores;
  final List<String> _recent;

  static const minPlayers = 3;
  static const maxPlayers = 20;
  static const _recentLimit = 80;

  String get installId => _storage.installId();

  // Context

  void setContext(PlayContext c) {
    playContext = c;
    if (c.adult) confirmAdult(notify: false);
    _storage.saveContext(c);
    notifyListeners();
  }

  void confirmAdult({bool notify = true}) {
    if (adultConfirmed) return;
    adultConfirmed = true;
    _storage.saveAdultConfirmed();
    if (notify) notifyListeners();
  }

  // Plugins

  bool has(FeaturePlugin f) => features.contains(f.id);
  bool get scoresOn => has(FeaturePlugin.scores);
  bool get votingOn => has(FeaturePlugin.voting) && appSettings.inAppVoting;

  void installFeature(FeaturePlugin f) {
    features = {...features, f.id};
    if (f == FeaturePlugin.voting) appSettings = appSettings.copyWith(inAppVoting: true);
    _storage.saveAppSettings(appSettings);
    _storage.saveFeatures(features);
    notifyListeners();
  }

  void removeFeature(FeaturePlugin f) {
    features = {...features}..remove(f.id);
    _storage.saveFeatures(features);
    notifyListeners();
  }

  bool hasStorePack(String id) => storePacks.any((p) => p.id == id);

  void installStorePack(WordPack pack) {
    storePacks = [for (final p in storePacks) if (p.id != pack.id) p, pack];
    _storage.saveStorePacks(storePacks);
    notifyListeners();
  }

  void removeStorePack(String id) {
    storePacks = [for (final p in storePacks) if (p.id != id) p];
    _dropSelection(id);
    _storage.saveStorePacks(storePacks);
    notifyListeners();
  }

  // Packs

  List<WordPack> get allPacks => [...customPacks, ...storePacks, ...builtinPacks];

  bool fitsContext(WordPack p) => playContext.audiences.contains(p.audience);

  /// Packs offered in the current context: own packs always, the rest by audience.
  List<WordPack> get contextPacks => [
        for (final p in customPacks) p,
        for (final p in [...storePacks, ...builtinPacks])
          if (fitsContext(p)) p,
      ];

  WordPack? packById(String id) {
    for (final p in allPacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Packs for the next game: the chosen ones that fit the context, otherwise
  /// every non-custom pack of the context.
  List<WordPack> get selectedPacks {
    final offered = contextPacks;
    final chosen = [
      for (final p in offered)
        if (gameSettings.packIds.contains(p.id) && p.words.isNotEmpty) p,
    ];
    if (chosen.isNotEmpty) return chosen;
    final defaults = [for (final p in offered) if (!customPacksIds.contains(p.id)) p];
    return defaults.isNotEmpty ? defaults : (offered.isNotEmpty ? offered : [fallbackPack]);
  }

  Set<String> get customPacksIds => {for (final p in customPacks) p.id};

  bool get hasManualSelection => selectedPacks.any((p) => gameSettings.packIds.contains(p.id));

  void togglePack(String id, bool on) {
    final ids = {...gameSettings.packIds};
    on ? ids.add(id) : ids.remove(id);
    updateGameSettings(gameSettings.copyWith(packIds: ids));
  }

  void clearPackSelection() {
    final offered = {for (final p in contextPacks) p.id};
    updateGameSettings(gameSettings.copyWith(packIds: {...gameSettings.packIds}..removeAll(offered)));
  }

  void savePack(WordPack pack) {
    final cleaned = pack.copyWith(words: dedupeWords(pack.words), builtin: false, fromStore: false);
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
    _dropSelection(id);
    _storage.saveCustomPacks(customPacks);
    notifyListeners();
  }

  void _dropSelection(String id) {
    if (gameSettings.packIds.contains(id)) {
      gameSettings = gameSettings.copyWith(packIds: {...gameSettings.packIds}..remove(id));
      _storage.saveGameSettings(gameSettings);
    }
  }

  String newPackId() => 'vlastni-${DateTime.now().microsecondsSinceEpoch}';

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

  // Rounds and scores

  Round startRound() {
    final round = engine.createRound(
      players: players,
      pool: engine.buildPool(selectedPacks),
      settings: gameSettings.clampedFor(players.length),
      recent: _recent.toSet(),
      audiences: playContext.audiences,
    );
    _recent.add(normalizeWord(round.entry.word));
    if (_recent.length > _recentLimit) _recent.removeRange(0, _recent.length - _recentLimit);
    _storage.saveRecent(_recent);
    return round;
  }

  void addPoints(Map<String, int> points) {
    if (!scoresOn) return;
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
