import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/app_state.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/logic/game_engine.dart';
import 'package:impostor/models/word_pack.dart';
import 'package:impostor/screens/reveal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _round = Round(
  entry: WordEntry(word: 'Lavice'),
  packName: 'Škola',
  roles: [
    PlayerRole(player: 'Ana', kind: RoleKind.impostor, cardText: ''),
    PlayerRole(player: 'Bob', kind: RoleKind.civilian, cardText: 'Lavice'),
    PlayerRole(player: 'Cyril', kind: RoleKind.detective, cardText: 'Lavice', intel: ['Ana']),
    PlayerRole(player: 'Dana', kind: RoleKind.jester, cardText: 'Lavice'),
    PlayerRole(player: 'Emil', kind: RoleKind.undercover, cardText: 'Židle'),
  ],
  order: [0, 1, 2, 3, 4],
  chaos: null,
);

Future<void> _pump(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await Storage.open(), [fallbackPack]);
  await tester.pumpWidget(AppScope(state: state, child: const MaterialApp(home: RevealScreen(round: _round))));
  await tester.pumpAndSettle();
}

/// Colours of every icon on the revealed card.
List<Color?> _iconColors(WidgetTester tester) => [
      for (final icon in tester.widgetList<Icon>(find.descendant(of: find.byType(FlipCard), matching: find.byType(Icon))))
        icon.color,
    ];

/// Decoration of the revealed card's surface.
Decoration? _cardSurface(WidgetTester tester) => tester
    .widget<Container>(find.descendant(of: find.byType(FlipCard), matching: find.byType(Container)).first)
    .decoration;

void main() {
  testWidgets('every role card looks the same from across the table', (tester) async {
    await _pump(tester);
    final surfaces = <Decoration?>[];
    final icons = <String>{};
    for (var i = 0; i < _round.roles.length; i++) {
      await tester.tap(find.text('Ukázat kartu'));
      await tester.pumpAndSettle();
      surfaces.add(_cardSurface(tester));
      icons.add(_iconColors(tester).join(','));
      // No glow or pulse around any card: it would light up the holder's face.
      expect(
        find.descendant(
          of: find.byType(FlipCard),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
          ),
        ),
        findsNothing,
        reason: 'card ${_round.roles[i].kind} has an extra glow',
      );
      await tester.tap(find.textContaining('Mám to, skrýt'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(surfaces.toSet(), hasLength(1), reason: 'role cards differ: $surfaces');
    expect(icons, hasLength(1), reason: 'role icons differ in colour: $icons');
    expect(find.text('Všichni mají kartu'), findsOneWidget);
  });
}
