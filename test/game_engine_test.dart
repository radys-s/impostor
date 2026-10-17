import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/logic/game_engine.dart';
import 'package:impostor/models/settings.dart';
import 'package:impostor/models/word_pack.dart';
import 'package:impostor/util/text.dart';

const players = ['Ana', 'Bob', 'Cyril', 'Dana', 'Eva', 'Filip'];

Round round(GameSettings s, {int seed = 1, List<String> who = players}) {
  final engine = GameEngine(Random(seed));
  return engine.createRound(players: who, pool: engine.buildPool([fallbackPack]), settings: s);
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
}
