import 'dart:math';

import '../models/play_context.dart';
import '../models/settings.dart';
import '../models/word_pack.dart';
import '../util/text.dart';
import 'events.dart';

enum RoleKind {
  /// Knows the secret word.
  civilian,

  /// Sees "IMPOSTOR" (optionally with a hint).
  impostor,

  /// Impostor in undercover mode: sees a similar word and does not know.
  undercover,

  /// Civilian who also sees who the impostors are.
  detective,

  /// Knows the word and wins alone when the group votes them out.
  jester,
}

class PlayerRole {
  const PlayerRole({
    required this.player,
    required this.kind,
    required this.cardText,
    this.hint,
    this.letter,
    this.intel = const [],
  });

  final String player;
  final RoleKind kind;

  /// Main text on the revealed card: the word, the similar word, or empty for a plain impostor.
  final String cardText;

  /// Hint for a plain impostor in hint mode.
  final String? hint;

  /// First letter of the word, given to plain impostors by an event.
  final String? letter;

  /// Names this player secretly knows: impostors for the detective,
  /// fellow impostors for allied impostors.
  final List<String> intel;

  bool get isImpostor => kind == RoleKind.impostor || kind == RoleKind.undercover;

  /// Knows the secret word (civilian, detective, jester).
  bool get knowsWord => !isImpostor;
}

class Round {
  const Round({
    required this.entry,
    required this.packName,
    required this.roles,
    required this.order,
    required this.chaos,
    this.event,
    this.eventLetter,
  });

  final WordEntry entry;
  final String packName;

  /// In seat order (the order players reveal cards).
  final List<PlayerRole> roles;

  /// Clue-giving order starting with a random player (indexes into [roles]).
  final List<int> order;

  /// Set when chaos mode produced 0 or all impostors.
  final ChaosKind? chaos;

  /// Twist announced on the round screen, if any.
  final RoundEvent? event;

  /// Public letter for [EventEffect.letter]; the impostor letter lives on the role.
  final String? eventLetter;

  List<PlayerRole> get impostors => [for (final r in roles) if (r.isImpostor) r];
  PlayerRole? roleOf(RoleKind kind) => roles.where((r) => r.kind == kind).firstOrNull;

  /// Discussion timer forced by the event, or null to use the settings.
  int? get eventTimer => event?.effect == EventEffect.timer ? event!.timerSeconds : null;
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
  static const chaosChance = 0.12;

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
    Set<Audience> audiences = const {Audience.family},
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
    final plainImpostors = !undercover && count > 0 && chaos == null;

    // Special roles come from civilians and always leave two plain ones.
    final free = seats.skip(count).toList();
    int? takeSpecial(bool wanted) => wanted && chaos == null && count > 0 && free.length > 2 ? free.removeLast() : null;
    final jesterSeat = takeSpecial(settings.jester);
    final detectiveSeat = takeSpecial(settings.detective);

    final event = pickEvent(settings.eventRate, audiences, plainImpostors: plainImpostors);
    final letter = switch (event?.effect) {
      EventEffect.letter => eventLetters[_random.nextInt(eventLetters.length)],
      EventEffect.impostorLetter => entry.word.substring(0, 1).toUpperCase(),
      _ => null,
    };

    final impostorNames = [for (final i in seats.take(count)) players[i]]..sort();
    final roles = <PlayerRole>[
      for (var i = 0; i < players.length; i++)
        if (i == jesterSeat)
          PlayerRole(player: players[i], kind: RoleKind.jester, cardText: entry.word)
        else if (i == detectiveSeat)
          PlayerRole(player: players[i], kind: RoleKind.detective, cardText: entry.word, intel: impostorNames)
        else if (!impostorSeats.contains(i))
          PlayerRole(player: players[i], kind: RoleKind.civilian, cardText: entry.word)
        else if (undercover)
          PlayerRole(player: players[i], kind: RoleKind.undercover, cardText: entry.similar)
        else
          PlayerRole(
            player: players[i],
            kind: RoleKind.impostor,
            cardText: '',
            hint: settings.hint && entry.hint.isNotEmpty ? entry.hint : (settings.hint ? picked.pack.name : null),
            letter: event?.effect == EventEffect.impostorLetter ? letter : null,
            intel: settings.allies && chaos == null ? [for (final n in impostorNames) if (n != players[i]) n] : const [],
          ),
    ];

    final start = _random.nextInt(players.length);
    var order = [for (var i = 0; i < players.length; i++) (start + i) % players.length];
    if (event?.effect == EventEffect.reverse) order = order.reversed.toList();

    return Round(
      entry: entry,
      packName: picked.pack.name,
      roles: roles,
      order: order,
      chaos: chaos,
      event: event,
      // The impostor letter is secret, so only the public letter rule is stored.
      eventLetter: event?.effect == EventEffect.letter ? letter : null,
    );
  }

  /// Rolls [rate] and picks an event allowed for [audiences].
  /// [plainImpostors] is false when no player would see an impostor-only hint.
  RoundEvent? pickEvent(EventRate rate, Set<Audience> audiences, {required bool plainImpostors}) {
    if (rate.chance <= 0 || _random.nextDouble() >= rate.chance) return null;
    final options = [
      for (final e in roundEvents)
        if (e.fits(audiences) && (plainImpostors || e.effect != EventEffect.impostorLetter)) e,
    ];
    if (options.isEmpty) return null;
    // Adult events get extra weight when they are allowed, so 18+ games feel 18+.
    final weighted = [
      for (final e in options) ...[e, if (e.audiences.length == 1 && e.audiences.first == Audience.adult) e],
    ];
    return weighted[_random.nextInt(weighted.length)];
  }
}

enum Winner { civilians, impostors, jester }

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
  final jester = round.roleOf(RoleKind.jester);
  if (!vote.tie && jester != null && vote.accused == jester.player) return Winner.jester;
  if (vote.tie || vote.accused == null || !impostors.contains(vote.accused)) {
    return Winner.impostors;
  }
  return impostorGuessedWord ? Winner.impostors : Winner.civilians;
}

/// Points: each civilian +1 on civilian win, each impostor +2 on impostor win,
/// the jester +3 alone when voted out (and +1 with civilians otherwise).
/// The "everybody" chaos round is just for fun and scores nothing.
Map<String, int> roundPoints(Round round, Winner winner) {
  final points = <String, int>{};
  final allImpostors = round.impostors.length == round.roles.length;
  for (final r in round.roles) {
    if (allImpostors) {
      points[r.player] = 0;
    } else if (r.kind == RoleKind.jester) {
      points[r.player] = switch (winner) { Winner.jester => 3, Winner.civilians => 1, Winner.impostors => 0 };
    } else if (r.isImpostor) {
      points[r.player] = winner == Winner.impostors ? 2 : 0;
    } else {
      points[r.player] = winner == Winner.civilians ? 1 : 0;
    }
  }
  return points;
}
