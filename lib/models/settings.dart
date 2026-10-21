import '../logic/events.dart';

/// Per-game options chosen on the setup screen.
class GameSettings {
  const GameSettings({
    this.packIds = const {},
    this.impostorMin = 1,
    this.impostorMax = 1,
    this.hint = false,
    this.undercover = false,
    this.chaos = false,
    this.timerSeconds = 0,
    this.eventRate = EventRate.often,
    this.detective = false,
    this.jester = false,
    this.allies = false,
  });

  final Set<String> packIds;

  /// When min == max the count is fixed, otherwise random in the range.
  final int impostorMin;
  final int impostorMax;
  final bool hint;
  final bool undercover;

  /// Occasionally nobody or everybody is the impostor.
  final bool chaos;

  /// 0 = no timer.
  final int timerSeconds;

  /// How often a round gets a twist (see roundEvents).
  final EventRate eventRate;

  /// One civilian also sees who the impostors are.
  final bool detective;

  /// One player knows the word and wins alone when voted out.
  final bool jester;

  /// Impostors see each other's names.
  final bool allies;

  bool get randomImpostors => impostorMax > impostorMin;

  GameSettings copyWith({
    Set<String>? packIds,
    int? impostorMin,
    int? impostorMax,
    bool? hint,
    bool? undercover,
    bool? chaos,
    int? timerSeconds,
    EventRate? eventRate,
    bool? detective,
    bool? jester,
    bool? allies,
  }) =>
      GameSettings(
        packIds: packIds ?? this.packIds,
        impostorMin: impostorMin ?? this.impostorMin,
        impostorMax: impostorMax ?? this.impostorMax,
        hint: hint ?? this.hint,
        undercover: undercover ?? this.undercover,
        chaos: chaos ?? this.chaos,
        timerSeconds: timerSeconds ?? this.timerSeconds,
        eventRate: eventRate ?? this.eventRate,
        detective: detective ?? this.detective,
        jester: jester ?? this.jester,
        allies: allies ?? this.allies,
      );

  /// Clamps impostor counts to what the player count allows (1..n-1).
  GameSettings clampedFor(int playerCount) {
    final upper = playerCount > 1 ? playerCount - 1 : 1;
    final min = impostorMin.clamp(1, upper);
    final max = impostorMax.clamp(min, upper);
    return copyWith(impostorMin: min, impostorMax: max);
  }

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
        packIds: {for (final id in (json['packIds'] as List? ?? const [])) id as String},
        impostorMin: json['impostorMin'] as int? ?? 1,
        impostorMax: json['impostorMax'] as int? ?? 1,
        hint: json['hint'] as bool? ?? false,
        undercover: json['undercover'] as bool? ?? false,
        chaos: json['chaos'] as bool? ?? false,
        timerSeconds: json['timerSeconds'] as int? ?? 0,
        eventRate: EventRate.parse(json['eventRate']),
        detective: json['detective'] as bool? ?? false,
        jester: json['jester'] as bool? ?? false,
        allies: json['allies'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'packIds': packIds.toList(),
        'impostorMin': impostorMin,
        'impostorMax': impostorMax,
        'hint': hint,
        'undercover': undercover,
        'chaos': chaos,
        'timerSeconds': timerSeconds,
        'eventRate': eventRate.name,
        'detective': detective,
        'jester': jester,
        'allies': allies,
      };
}

/// App-wide preferences from the Settings screen.
class AppSettings {
  const AppSettings({this.inAppVoting = false, this.haptics = true});

  /// false = players vote out loud and the app only reveals (default).
  final bool inAppVoting;
  final bool haptics;

  AppSettings copyWith({bool? inAppVoting, bool? haptics}) =>
      AppSettings(inAppVoting: inAppVoting ?? this.inAppVoting, haptics: haptics ?? this.haptics);

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        inAppVoting: json['inAppVoting'] as bool? ?? false,
        haptics: json['haptics'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'inAppVoting': inAppVoting, 'haptics': haptics};
}
