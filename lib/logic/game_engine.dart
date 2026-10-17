import 'dart:math';

import '../models/settings.dart';
import '../models/word_pack.dart';
import '../util/text.dart';

enum RoleKind {
  /// Knows the secret word.
  civilian,

  /// Sees "IMPOSTOR" (optionally with a hint).
  impostor,

  /// Impostor in undercover mode: sees a similar word and does not know.
  undercover,
}

class PlayerRole {
  const PlayerRole({required this.player, required this.kind, required this.cardText, this.hint});

  final String player;
  final RoleKind kind;

  /// Main text on the revealed card: the word, the similar word, or empty for a plain impostor.
  final String cardText;

  /// Hint for a plain impostor in hint mode.
  final String? hint;

  bool get isImpostor => kind != RoleKind.civilian;
}

class Round {
  const Round({
    required this.entry,
    required this.packName,
    required this.roles,
    required this.order,
    required this.chaos,
  });

  final WordEntry entry;
  final String packName;

  /// In seat order (the order players reveal cards).
  final List<PlayerRole> roles;

  /// Clue-giving order starting with a random player (indexes into [roles]).
  final List<int> order;

  /// Set when chaos mode produced 0 or all impostors.
  final ChaosKind? chaos;

  List<PlayerRole> get impostors => [for (final r in roles) if (r.isImpostor) r];
  String get startingPlayer => roles[order.first].player;
}

enum ChaosKind { nobody, everybody }

class PoolEntry {
  const PoolEntry(this.entry, this.pack);
  final WordEntry entry;
  final WordPack pack;
}

class GameEngine {
  GameEngine([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// Chance for each of the chaos outcomes when chaos mode is on.
  static const chaosChance = 0.08;

  List<PoolEntry> buildPool(Iterable<WordPack> packs) => [
        for (final p in packs)
          for (final w in p.words) PoolEntry(w, p),
      ];

  /// Picks a word, avoiding [recent] normalized words while possible.
  PoolEntry pickEntry(List<PoolEntry> pool, Set<String> recent) {
    if (pool.isEmpty) throw StateError('Žádná slova k výběru');
    final fresh = [for (final e in pool) if (!recent.contains(normalizeWord(e.entry.word))) e];
    final source = fresh.isEmpty ? pool : fresh;
    return source[_random.nextInt(source.length)];
  }

  int impostorCount(int players, GameSettings settings) {
    final s = settings.clampedFor(players);
    return s.impostorMin + _random.nextInt(s.impostorMax - s.impostorMin + 1);
  }

  Round createRound({
    required List<String> players,
    required List<PoolEntry> pool,
    required GameSettings settings,
    Set<String> recent = const {},
  }) {
    if (players.length < 3) throw ArgumentError('Potřeba aspoň 3 hráči');
    final picked = pickEntry(pool, recent);
    final entry = picked.entry;

    ChaosKind? chaos;
    var count = impostorCount(players.length, settings);
    if (settings.chaos) {
      final roll = _random.nextDouble();
      if (roll < chaosChance) {
        chaos = ChaosKind.nobody;
        count = 0;
      } else if (roll < chaosChance * 2) {
        chaos = ChaosKind.everybody;
        count = players.length;
      }
    }

    final seats = List<int>.generate(players.length, (i) => i)..shuffle(_random);
    final impostorSeats = seats.take(count).toSet();
    final undercover = settings.undercover && entry.similar.isNotEmpty;

    final roles = <PlayerRole>[
      for (var i = 0; i < players.length; i++)
        if (!impostorSeats.contains(i))
          PlayerRole(player: players[i], kind: RoleKind.civilian, cardText: entry.word)
        else if (undercover)
          PlayerRole(player: players[i], kind: RoleKind.undercover, cardText: entry.similar)
        else
          PlayerRole(
            player: players[i],
            kind: RoleKind.impostor,
            cardText: '',
            hint: settings.hint && entry.hint.isNotEmpty ? entry.hint : (settings.hint ? picked.pack.name : null),
          ),
    ];

    final start = _random.nextInt(players.length);
    final order = [for (var i = 0; i < players.length; i++) (start + i) % players.length];

    return Round(entry: entry, packName: picked.pack.name, roles: roles, order: order, chaos: chaos);
  }
}

enum Winner { civilians, impostors }

class VoteOutcome {
  const VoteOutcome({required this.tally, required this.accused, required this.tie});

  /// Votes per accused player name; key null = "nobody is the impostor".
  final Map<String?, int> tally;

  /// Player with the most votes, null when the group voted "nobody" or tie.
  final String? accused;
  final bool tie;

  bool get votedNobody => !tie && accused == null;
}

/// Counts secret votes. [votes] maps voter -> accused (null = nobody).
VoteOutcome tallyVotes(Map<String, String?> votes) {
  final tally = <String?, int>{};
  for (final target in votes.values) {
    tally[target] = (tally[target] ?? 0) + 1;
  }
  if (tally.isEmpty) return const VoteOutcome(tally: {}, accused: null, tie: true);
  final top = tally.values.reduce(max);
  final leaders = [for (final e in tally.entries) if (e.value == top) e.key];
  if (leaders.length > 1) return VoteOutcome(tally: tally, accused: null, tie: true);
  return VoteOutcome(tally: tally, accused: leaders.single, tie: false);
}

/// Decides who won after voting.
/// [impostorGuessedWord] only matters when an impostor was caught.
Winner decideWinner(Round round, VoteOutcome vote, {bool impostorGuessedWord = false}) {
  final impostors = {for (final r in round.impostors) r.player};
  if (impostors.isEmpty) {
    return vote.votedNobody ? Winner.civilians : Winner.impostors;
  }
  if (impostors.length == round.roles.length) {
    // Everybody was the impostor: there is nobody to catch.
    return Winner.impostors;
  }
  if (vote.tie || vote.accused == null || !impostors.contains(vote.accused)) {
    return Winner.impostors;
  }
  return impostorGuessedWord ? Winner.impostors : Winner.civilians;
}

/// Points: each civilian +1 on civilian win, each impostor +2 on impostor win.
/// The "everybody" chaos round is just for fun and scores nothing.
Map<String, int> roundPoints(Round round, Winner winner) {
  final points = <String, int>{};
  final allImpostors = round.impostors.length == round.roles.length;
  for (final r in round.roles) {
    if (allImpostors) {
      points[r.player] = 0;
    } else if (r.isImpostor) {
      points[r.player] = winner == Winner.impostors ? 2 : 0;
    } else {
      points[r.player] = winner == Winner.civilians ? 1 : 0;
    }
  }
  return points;
}
