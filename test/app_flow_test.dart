import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/app_state.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/main.dart';
import 'package:impostor/screens/players_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await Storage.open();
  final state = AppState(storage, [fallbackPack]);
  await tester.pumpWidget(ImpostorApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> revealAll(WidgetTester tester, int players) async {
  for (var i = 0; i < players; i++) {
    await tester.tap(find.text('Ukázat kartu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skrýt kartu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(i == players - 1 ? 'Všichni viděli, jdeme hrát' : 'Další hráč'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('start is disabled until 3 players are added', (tester) async {
    final state = await pumpApp(tester);
    expect(find.textContaining('Přidej ještě 3'), findsOneWidget);

    await tester.tap(find.text('0 hráčů'));
    await tester.pumpAndSettle();
    for (final name in ['Ana', 'Bob', 'Cyril']) {
      await tester.enterText(find.byType(TextField), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(state.players, ['Ana', 'Bob', 'Cyril']);

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Tohle jméno už ve hře je'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PlayersScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Začít hru'), findsOneWidget);
  });

  testWidgets('verbal round: reveal cards, reveal impostor, record win', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril', 'Dana'],
    });
    await tester.tap(find.text('Začít hru'));
    await tester.pumpAndSettle();
    await revealAll(tester, 4);

    expect(find.text('Začíná'), findsOneWidget);
    await tester.tap(find.text('Odhalit impostora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odhalit'));
    await tester.pumpAndSettle();
    expect(find.text('Tajné slovo'), findsOneWidget);

    await tester.tap(find.text('Hráči'));
    await tester.pumpAndSettle();
    expect(state.scores.values.where((v) => v == 1), hasLength(3));
    expect(find.text('Další kolo'), findsOneWidget);
  });

  testWidgets('in-app voting round catches impostor', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
      'appSettings': '{"inAppVoting":true,"haptics":false}',
    });
    await tester.tap(find.text('Začít hru'));
    await tester.pumpAndSettle();

    // Peek at the round through the state's engine output on the reveal screen.
    await revealAll(tester, 3);
    await tester.tap(find.text('Hlasovat'));
    await tester.pumpAndSettle();

    // Everyone votes for the first listed other player; result must be consistent.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Jsem to já, hlasovat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Odhalit'));
    await tester.pumpAndSettle();
    if (find.text('Uhodl').evaluate().isNotEmpty) {
      await tester.tap(find.text('Neuhodl'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Další kolo'), findsOneWidget);
    expect(state.scores.values.fold<int>(0, (a, b) => a + b), anyOf(2, 3));
  });
}
