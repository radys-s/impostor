import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/logic/events.dart';
import 'package:impostor/logic/game_engine.dart';
import 'package:impostor/models/play_context.dart';
import 'package:impostor/models/settings.dart';
import 'package:impostor/models/word_pack.dart';
import 'package:impostor/util/text.dart';

const players = ['Ana', 'Bob', 'Cyril', 'Dana', 'Eva', 'Filip'];

Round round(GameSettings s, {int seed = 1, List<String> who = players, Set<Audience>? audiences}) {
  final engine = GameEngine(Random(seed));
  final pool = engine.buildPool([fallbackPack]);
  return audiences == null
      ? engine.createRound(players: who, pool: pool, settings: s)
      : engine.createRound(players: who, pool: pool, settings: s, audiences: audiences);
}

void main() {
  test('classic round: one impostor with empty card, others see word', () {
    for (var seed = 0; seed < 200; seed++) {
      final r = round(const GameSettings(), seed: seed);
      expect(r.impostors, hasLength(1));
      expect(r.impostors.single.kind, RoleKind.impostor);
      expect(r.impostors.single.cardText, isEmpty);
      expect(r.impostors.single.hint, isNull);
      for (final c in r.roles.where((r) => !r.isImpostor)) {
        expect(c.cardText, r.entry.word);
      }
      expect(r.order.toSet(), hasLength(players.length));
    }
  });

  test('impostor is spread across all seats', () {
    final counts = <String, int>{};
    for (var seed = 0; seed < 3000; seed++) {
      final name = round(const GameSettings(), seed: seed).impostors.single.player;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    expect(counts.keys.toSet(), players.toSet());
    for (final c in counts.values) {
      expect(c, inInclusiveRange(380, 620)); // expected 500
    }
  });

  test('random impostor range stays in bounds and hits both ends', () {
    final seen = <int>{};
    for (var seed = 0; seed < 300; seed++) {
      final n = round(const GameSettings(impostorMin: 1, impostorMax: 3), seed: seed).impostors.length;
      expect(n, inInclusiveRange(1, 3));
      seen.add(n);
    }
    expect(seen, {1, 2, 3});
  });

  test('impostor count is clamped to players - 1', () {
    final r = round(const GameSettings(impostorMin: 5, impostorMax: 9), who: ['A', 'B', 'C']);
    expect(r.impostors, hasLength(2));
  });

  test('hint mode gives the entry hint', () {
    final r = round(const GameSettings(hint: true));
    expect(r.impostors.single.hint, r.entry.hint);
  });

  test('hint mode falls back to pack name when entry has no hint', () {
    final engine = GameEngine(Random(3));
    const pack = WordPack(id: 'x', name: 'Ovoce', words: [WordEntry(word: 'Jablko')]);
    final r = engine.createRound(players: players, pool: engine.buildPool([pack]), settings: const GameSettings(hint: true));
    expect(r.impostors.single.hint, 'Ovoce');
  });

  test('undercover mode gives similar word and undercover kind', () {
    final r = round(const GameSettings(undercover: true, hint: true));
    expect(r.impostors.single.kind, RoleKind.undercover);
    expect(r.impostors.single.cardText, r.entry.similar);
    expect(r.impostors.single.cardText, isNot(r.entry.word));
  });

  test('undercover without similar word falls back to classic impostor', () {
    final engine = GameEngine(Random(3));
    const pack = WordPack(id: 'x', name: 'X', words: [WordEntry(word: 'Jablko')]);
    final r = engine.createRound(players: players, pool: engine.buildPool([pack]), settings: const GameSettings(undercover: true));
    expect(r.impostors.single.kind, RoleKind.impostor);
  });

  test('chaos mode sometimes produces nobody and everybody', () {
    final kinds = <ChaosKind?>{};
    for (var seed = 0; seed < 500; seed++) {
      final r = round(const GameSettings(chaos: true), seed: seed);
      kinds.add(r.chaos);
      if (r.chaos == ChaosKind.nobody) expect(r.impostors, isEmpty);
      if (r.chaos == ChaosKind.everybody) expect(r.impostors, hasLength(players.length));
      if (r.chaos == null) expect(r.impostors, hasLength(1));
    }
    expect(kinds, {null, ChaosKind.nobody, ChaosKind.everybody});
  });

  test('no chaos without chaos mode', () {
    for (var seed = 0; seed < 500; seed++) {
      expect(round(const GameSettings(), seed: seed).chaos, isNull);
    }
  });

  test('recent words are avoided while fresh ones exist', () {
    final engine = GameEngine(Random(1));
    final pool = engine.buildPool([fallbackPack]);
    final recent = {for (final w in fallbackPack.words.skip(1)) normalizeWord(w.word)};
    for (var i = 0; i < 50; i++) {
      expect(engine.pickEntry(pool, recent).entry.word, fallbackPack.words.first.word);
    }
  });

  test('fewer than 3 players is rejected', () {
    expect(() => round(const GameSettings(), who: ['A', 'B']), throwsArgumentError);
  });

  group('voting', () {
    Round fixed() => const Round(
          entry: WordEntry(word: 'Pes'),
          packName: 'X',
          roles: [
            PlayerRole(player: 'A', kind: RoleKind.impostor, cardText: ''),
            PlayerRole(player: 'B', kind: RoleKind.civilian, cardText: 'Pes'),
            PlayerRole(player: 'C', kind: RoleKind.civilian, cardText: 'Pes'),
          ],
          order: [0, 1, 2],
          chaos: null,
        );

    test('tally finds majority and ties', () {
      expect(tallyVotes({'A': 'B', 'B': 'A', 'C': 'A'}).accused, 'A');
      expect(tallyVotes({'A': 'B', 'B': 'A', 'C': null}).tie, isTrue);
      expect(tallyVotes({'A': null, 'B': null, 'C': 'A'}).votedNobody, isTrue);
    });

    test('catching impostor wins for civilians unless word guessed', () {
      final vote = tallyVotes({'A': 'B', 'B': 'A', 'C': 'A'});
      expect(decideWinner(fixed(), vote), Winner.civilians);
      expect(decideWinner(fixed(), vote, impostorGuessedWord: true), Winner.impostors);
    });

    test('wrong accusation or tie wins for impostor', () {
      expect(decideWinner(fixed(), tallyVotes({'A': 'B', 'B': 'C', 'C': 'B'})), Winner.impostors);
      expect(decideWinner(fixed(), tallyVotes({'A': 'B', 'B': 'A', 'C': null})), Winner.impostors);
    });

    test('nobody chaos: voting nobody wins for civilians', () {
      const r = Round(
        entry: WordEntry(word: 'Pes'),
        packName: 'X',
        roles: [
          PlayerRole(player: 'A', kind: RoleKind.civilian, cardText: 'Pes'),
          PlayerRole(player: 'B', kind: RoleKind.civilian, cardText: 'Pes'),
          PlayerRole(player: 'C', kind: RoleKind.civilian, cardText: 'Pes'),
        ],
        order: [0, 1, 2],
        chaos: ChaosKind.nobody,
      );
      expect(decideWinner(r, tallyVotes({'A': null, 'B': null, 'C': 'A'})), Winner.civilians);
      expect(decideWinner(r, tallyVotes({'A': 'B', 'B': 'C', 'C': 'B'})), Winner.impostors);
      expect(roundPoints(r, Winner.impostors).values.every((p) => p == 0), isTrue);
    });

    test('points: civilians +1, impostors +2', () {
      expect(roundPoints(fixed(), Winner.civilians), {'A': 0, 'B': 1, 'C': 1});
      expect(roundPoints(fixed(), Winner.impostors), {'A': 2, 'B': 0, 'C': 0});
    });
  });

  test('normalizeWord strips diacritics and case', () {
    expect(normalizeWord('  Řízek  Šťávy '), 'rizek stavy');
    expect(dedupeWords(const [WordEntry(word: 'Kůň'), WordEntry(word: 'kun'), WordEntry(word: '')]), hasLength(1));
  });
  group('events', () {
    test('rate off never gives an event, always always does', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(round(const GameSettings(eventRate: EventRate.off), seed: seed).event, isNull);
        expect(round(const GameSettings(eventRate: EventRate.always), seed: seed).event, isNotNull);
      }
    });

    test('often is roughly 60 %', () {
      var hits = 0;
      for (var seed = 0; seed < 2000; seed++) {
        if (round(const GameSettings(), seed: seed).event != null) hits++;
      }
      expect(hits, inInclusiveRange(1050, 1350));
    });

    test('family games never get adult or teen events', () {
      for (var seed = 0; seed < 500; seed++) {
        final e = round(const GameSettings(eventRate: EventRate.always), seed: seed, audiences: {Audience.family})
            .event!;
        expect(e.audiences, contains(Audience.family));
      }
    });

    test('freaky games get adult events often', () {
      var adult = 0;
      for (var seed = 0; seed < 500; seed++) {
        final e = round(const GameSettings(eventRate: EventRate.always), seed: seed, audiences: {Audience.adult})
            .event!;
        if (!e.audiences.contains(Audience.family)) adult++;
      }
      expect(adult, greaterThan(250));
    });

    test('letter events set a letter; impostor letter reaches the impostor card', () {
      var seen = 0;
      for (var seed = 0; seed < 600; seed++) {
        final r = round(const GameSettings(eventRate: EventRate.always), seed: seed);
        switch (r.event!.effect) {
          case EventEffect.letter:
            expect(eventLetters, contains(r.eventLetter));
          case EventEffect.impostorLetter:
            seen++;
            expect(r.impostors.single.letter, r.entry.word.substring(0, 1).toUpperCase());
          case EventEffect.reverse:
          case EventEffect.timer:
            expect(r.eventTimer, r.event!.effect == EventEffect.timer ? 60 : null);
          case EventEffect.none:
            expect(r.eventLetter, isNull);
        }
      }
      expect(seen, greaterThan(0));
    });

    test('impostor letter is never picked in undercover rounds', () {
      for (var seed = 0; seed < 500; seed++) {
        final r = round(const GameSettings(eventRate: EventRate.always, undercover: true), seed: seed);
        if (r.entry.similar.isEmpty) continue;
        expect(r.event!.effect, isNot(EventEffect.impostorLetter));
      }
    });
  });

  group('special roles', () {
    const all = GameSettings(detective: true, jester: true, allies: true, impostorMin: 2, impostorMax: 2);

    test('detective sees impostors, jester knows the word, allies see each other', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = round(all, seed: seed);
        final names = {for (final i in r.impostors) i.player};
        final detective = r.roleOf(RoleKind.detective)!;
        expect(detective.intel.toSet(), names);
        expect(detective.cardText, r.entry.word);
        expect(r.roleOf(RoleKind.jester)!.cardText, r.entry.word);
        for (final i in r.impostors) {
          expect(i.intel, [for (final n in names) if (n != i.player) n]..sort());
        }
        expect(r.roles.where((x) => x.kind == RoleKind.civilian).length, 2);
      }
    });

    test('special roles need two plain civilians left', () {
      final r = round(all, who: const ['Ana', 'Bob', 'Cyril', 'Dana']);
      expect(r.roleOf(RoleKind.jester), isNull);
      expect(r.roleOf(RoleKind.detective), isNull);
      final five = round(all, who: const ['Ana', 'Bob', 'Cyril', 'Dana', 'Eva']);
      expect(five.roleOf(RoleKind.jester), isNotNull);
      expect(five.roleOf(RoleKind.detective), isNull);
    });

    test('voting out the jester wins for the jester alone', () {
      final r = round(all);
      final jester = r.roleOf(RoleKind.jester)!.player;
      final vote = tallyVotes({for (final p in players) p: jester});
      final winner = decideWinner(r, vote);
      expect(winner, Winner.jester);
      final points = roundPoints(r, winner);
      expect(points[jester], 3);
      expect(points.values.where((v) => v > 0), hasLength(1));
    });

    test('jester scores with civilians when an impostor is caught', () {
      final r = round(all);
      final vote = tallyVotes({for (final p in players) p: r.impostors.first.player});
      final points = roundPoints(r, decideWinner(r, vote));
      expect(points[r.roleOf(RoleKind.jester)!.player], 1);
      expect(points[r.roleOf(RoleKind.detective)!.player], 1);
    });
  });
}
