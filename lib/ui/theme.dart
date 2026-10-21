import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/play_context.dart';

/// Party palette. Context gradients live in [PlayContext].
abstract final class Party {
  static const red = Color(0xFFFF3D57);
  static const orange = Color(0xFFFF6B1A);
  static const yellow = Color(0xFFFFB800);
  static const green = Color(0xFF16C784);
  static const pink = Color(0xFFFF2E88);
  static const violet = Color(0xFF8A2BE2);

  /// Impostor card colour, the same in every context.
  static const impostor = LinearGradient(
    colors: [Color(0xFFFF2E4D), Color(0xFFB0124A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const blue = Color(0xFF2EC5FF);

  /// Detective card: cool blue, clearly not the red impostor.
  static const detective = LinearGradient(
    colors: [Color(0xFF2EC5FF), Color(0xFF5B3CF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Jester card: loud yellow to green.
  static const jester = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFF16C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const confetti = [red, orange, yellow, green, pink, blue];
}

ThemeData buildTheme(Brightness brightness, PlayContext context) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: context.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  // Warm neutrals instead of the cold default greys.
  final scheme = base.copyWith(
    surface: dark ? const Color(0xFF141015) : const Color(0xFFFFF8F2),
    surfaceContainerLowest: dark ? const Color(0xFF0E0B0F) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1A151B) : const Color(0xFFFFF2E8),
    surfaceContainer: dark ? const Color(0xFF201A21) : const Color(0xFFFCEDE2),
    surfaceContainerHigh: dark ? const Color(0xFF272028) : const Color(0xFFF8E7DB),
    surfaceContainerHighest: dark ? const Color(0xFF302731) : const Color(0xFFF3DFD2),
  );
  final text = Typography.material2021(platform: TargetPlatform.iOS).black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primaryContainer,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? context.accent : null),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.accent, width: 2),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 18)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Light haptic tick, respects the app setting.
void tick(bool enabled) {
  if (enabled) HapticFeedback.selectionClick();
}

void buzz(bool enabled) {
  if (enabled) HapticFeedback.heavyImpact();
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
