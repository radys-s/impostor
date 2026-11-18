import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/app_state.dart';
import 'package:impostor/data/storage.dart';
import 'package:impostor/main.dart';
import 'package:impostor/models/play_context.dart';
import 'package:impostor/screens/home_screen.dart';
import 'package:impostor/screens/players_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the app can be played from the keyboard', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await Storage.open(), [fallbackPack]);
    await tester.pumpWidget(ImpostorApp(state: state));
    await tester.pumpAndSettle();

    // Tab reaches the first context tile, Enter picks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(state.playContext, PlayContext.family);

    // Tab reaches the main button on Home, Space presses it.
    final target = Focus.of(tester.element(find.text('Přidej ještě 3 hráče')));
    for (var i = 0; i < 20 && FocusManager.instance.primaryFocus != target; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(FocusManager.instance.primaryFocus, target);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(PlayersScreen), findsOneWidget);
  });
}
