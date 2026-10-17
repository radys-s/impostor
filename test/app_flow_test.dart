import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/app_state.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/main.dart';
import 'package:impostor/models/play_context.dart';
import 'package:impostor/screens/home_screen.dart';
import 'package:impostor/screens/players_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app with reduced motion (ambient loops would never settle) and
/// picks [context] on the startup screen.
Future<AppState> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String context = 'Kamarádi',
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await Storage.open();
  final state = AppState(storage, [fallbackPack]);
  await tester.pumpWidget(ImpostorApp(state: state));
  await tester.pumpAndSettle();
  expect(find.text('S kým dneska hraješ?'), findsOneWidget);
  await tester.tap(find.text(context));
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
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Přidej ještě 3'), findsOneWidget);

    await tester.tap(find.text('Přidej hráče'));
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
    expect(find.text('Rozdat karty'), findsOneWidget);
  });

  testWidgets('adult context asks for 18+ confirmation once', (tester) async {
    final state = await pumpApp(tester, context: 'Rodina');
    expect(state.playContext, PlayContext.family);

    await tester.tap(find.text('Rodina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freaky'));
    await tester.pumpAndSettle();
    expect(find.text('Jen pro dospělé'), findsOneWidget);
    await tester.tap(find.text('Je nám 18+'));
    await tester.pumpAndSettle();
    expect(state.playContext, PlayContext.freaky);
    expect(state.adultConfirmed, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('verbal round without plugins: reveal only, no scoring', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril', 'Dana'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 4);

    expect(find.text('ZAČÍNÁ'), findsOneWidget);
    await tester.tap(find.text('Odhalit impostora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odhalit'));
    await tester.pumpAndSettle();
    expect(find.text('Tajné slovo'), findsOneWidget);
    expect(find.text('Kdo bere body?'), findsNothing);
    expect(find.text('Další kolo'), findsOneWidget);
    expect(state.scores, isEmpty);
  });

  testWidgets('scores plugin: verbal round records the win', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril', 'Dana'],
      'features': ['skore'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 4);
    await tester.tap(find.text('Odhalit impostora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odhalit'));
    await tester.pumpAndSettle();

    // Chaos is off, so there is exactly one impostor and "Hráči" is offered.
    await tester.tap(find.text('Hráči'));
    await tester.pumpAndSettle();
    expect(state.scores.values.where((v) => v == 1), hasLength(3));
    expect(find.text('Další kolo'), findsOneWidget);
  });

  testWidgets('voting plugin: in-app voting round finishes', (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
      'features': ['hlasovani'],
      'appSettings': '{"inAppVoting":true,"haptics":false}',
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 3);
    await tester.tap(find.text('Hlasovat'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Jsem to já, hlasovat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.how_to_vote_outlined).first);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Nejvíc hlasů'), findsOneWidget);
    await tester.tap(find.text('Odhalit'));
    await tester.pumpAndSettle();
    if (find.text('Uhodl').evaluate().isNotEmpty) {
      await tester.tap(find.text('Neuhodl'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Další kolo'), findsOneWidget);
  });
}
