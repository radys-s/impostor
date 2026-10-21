import 'package:flutter/material.dart';

import '../logic/events.dart';
import 'settings.dart';

/// One-tap game modes on the options screen. Each one overwrites the rules
/// but keeps the chosen packs.
enum GamePreset {
  classic(
    label: 'Klasika',
    subtitle: 'Jeden impostor, občas event',
    icon: Icons.style_rounded,
  ),
  party(
    label: 'Párty',
    subtitle: 'Event každé kolo, šašek, chaos',
    icon: Icons.celebration_rounded,
  ),
  detective(
    label: 'Detektivka',
    subtitle: 'Detektiv proti spolčeným impostorům',
    icon: Icons.manage_search_rounded,
  ),
  hardcore(
    label: 'Hardcore',
    subtitle: 'Undercover, náhodný počet, 2 min',
    icon: Icons.whatshot_rounded,
  );

  const GamePreset({required this.label, required this.subtitle, required this.icon});

  final String label;
  final String subtitle;
  final IconData icon;

  GameSettings apply(GameSettings s, int players) {
    final base = GameSettings(packIds: s.packIds);
    return switch (this) {
      GamePreset.classic => base.copyWith(eventRate: EventRate.sometimes),
      GamePreset.party => base.copyWith(
          hint: true,
          chaos: true,
          jester: true,
          eventRate: EventRate.always,
          timerSeconds: 180,
        ),
      GamePreset.detective => base.copyWith(
          impostorMin: players >= 6 ? 2 : 1,
          impostorMax: players >= 6 ? 2 : 1,
          detective: true,
          allies: true,
          eventRate: EventRate.sometimes,
          timerSeconds: 300,
        ),
      GamePreset.hardcore => base.copyWith(
          impostorMin: 1,
          impostorMax: players >= 5 ? 2 : 1,
          undercover: true,
          chaos: true,
          jester: true,
          eventRate: EventRate.often,
          timerSeconds: 120,
        ),
    }.clampedFor(players);
  }

  /// True when [s] has exactly the rules this preset sets.
  bool matches(GameSettings s, int players) {
    final a = apply(s, players).toJson()..remove('packIds');
    final b = s.clampedFor(players).toJson()..remove('packIds');
    return a.entries.every((e) => b[e.key] == e.value);
  }
}
