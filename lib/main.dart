import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'data/storage.dart';
import 'screens/context_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.open();
  final packs = await loadBuiltinPacks();
  runApp(ImpostorApp(state: AppState(storage, packs)));
}

class ImpostorApp extends StatelessWidget {
  const ImpostorApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // Theme follows the chosen context, so the whole app re-tints on change.
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Impostor',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, state.playContext),
          darkTheme: buildTheme(Brightness.dark, state.playContext),
          themeMode: ThemeMode.system,
          themeAnimationDuration: const Duration(milliseconds: 450),
          locale: const Locale('cs'),
          supportedLocales: const [Locale('cs')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const ContextScreen(),
        ),
      ),
    );
  }
}
