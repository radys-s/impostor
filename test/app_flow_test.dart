import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/app_state.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/main.dart';
import 'package:impostor/models/play_context.dart';
import 'package:impostor/logic/events.dart';
import 'package:impostor/screens/game_options_screen.dart';
import 'package:impostor/screens/home_screen.dart';
import 'package:impostor/screens/players_screen.dart';
import 'package:impostor/screens/round_screen.dart';
import 'package:impostor/ui/widgets.dart';
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
    await tester.tap(find.textContaining('Mám to, skrýt'));
    await tester.pumpAndSettle();
    // Let the accidental double-tap lock expire before the next player.
    await tester.pump(const Duration(seconds: 1));
  }
  // Hiding the last card starts the round: no extra "start" stop.
  expect(find.byType(RoundScreen), findsOneWidget);
}

/// Presses [finder] long enough to trigger a hold-to-confirm button.
Future<void> hold(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pumpAndSettle();
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

  testWidgets('players screen: ready to type, and a removed player can be restored', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob'],
    });
    await tester.tap(find.text('2 hráči'));
    await tester.pumpAndSettle();
    // Players are still missing, so the name field is focused on arrival.
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.tap(find.byTooltip('Odebrat').first);
    await tester.pumpAndSettle();
    expect(state.players, ['Bob']);
    expect(find.text('Ana už nehraje'), findsOneWidget);
    await tester.tap(find.text('Vrátit'));
    await tester.pumpAndSettle();
    expect(state.players, ['Ana', 'Bob']);

    // The undo offer times out, and it does not follow the players into the game.
    await tester.tap(find.byTooltip('Odebrat').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Ana už nehraje'), findsNothing);
    await tester.tap(find.byTooltip('Odebrat').first);
    await tester.pumpAndSettle();
    expect(find.text('Bob už nehraje'), findsOneWidget);
    Navigator.of(tester.element(find.byType(PlayersScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Bob už nehraje'), findsNothing);
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
    await hold(tester, find.byType(HoldButton));
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
    await hold(tester, find.byType(HoldButton));

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
    await hold(tester, find.byType(HoldButton));

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

  testWidgets('quick second tap after hiding does not open the next card', (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ukázat kartu'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Mám to, skrýt'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Ukázat kartu'));
    await tester.pumpAndSettle();
    expect(find.text('Zapamatuj si to'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a quick tap on the round screen does not reveal the impostor', (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 3);

    // A normal press (300 ms) is not a hold, even with reduced motion on.
    final press = await tester.startGesture(tester.getCenter(find.byType(HoldButton)));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(RoundScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // A stray tap, or the last player's double tap, must not end the round.
    await tester.tap(find.byType(HoldButton));
    await tester.pump();
    await tester.tap(find.byType(HoldButton));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RoundScreen), findsOneWidget);
    expect(find.text('Tajné slovo'), findsNothing);
    expect(find.text('Drž, dokud se nenaplní'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Podrž a odhal impostora'), findsOneWidget);

    await hold(tester, find.byType(HoldButton));
    expect(find.text('Tajné slovo'), findsOneWidget);
  });

  testWidgets('the hold button also works from the keyboard', (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 3);
    Focus.of(tester.element(find.text('Podrž a odhal impostora'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Tajné slovo'), findsOneWidget);
  });

  testWidgets("the last player's double tap starts the round but reveals nothing", (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Ukázat kartu'));
      await tester.pumpAndSettle();
      final hide = tester.getCenter(find.textContaining('Mám to, skrýt'));
      await tester.tapAt(hide);
      if (i == 2) {
        // Second tap of a double tap, same spot, before anything settles.
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(hide);
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(RoundScreen), findsOneWidget);
    expect(find.text('Tajné slovo'), findsNothing);
  });

  testWidgets('round: forgotten word peek and leaving the round', (tester) async {
    await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril'],
    });
    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 3);

    await tester.tap(find.byTooltip('Někdo zapomněl slovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();
    expect(find.text('Skrýt'), findsOneWidget);
    await tester.tap(find.text('Skrýt'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ukončit kolo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ukončit'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets('party preset: every round shows an event and specials', (tester) async {
    final state = await pumpApp(tester, prefs: {
      'players': ['Ana', 'Bob', 'Cyril', 'Dana', 'Eva'],
    });
    await tester.tap(find.textContaining('Impostoři:'));
    await tester.pumpAndSettle();
    expect(find.byType(GameOptionsScreen), findsOneWidget);
    await tester.tap(find.text('Párty'));
    await tester.pumpAndSettle();
    expect(state.gameSettings.eventRate, EventRate.always);
    expect(state.gameSettings.jester, isTrue);
    Navigator.of(tester.element(find.byType(GameOptionsScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Párty'), findsOneWidget);

    await tester.tap(find.text('Rozdat karty'));
    await tester.pumpAndSettle();
    await revealAll(tester, 5);
    expect(find.text('EVENT KOLA'), findsOneWidget);
    await hold(tester, find.byType(HoldButton));
    expect(find.text('Tajné slovo'), findsOneWidget);
  });
}
