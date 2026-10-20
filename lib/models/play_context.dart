import 'package:flutter/material.dart';

/// Who a word pack is suitable for.
enum Audience {
  family,
  friends,
  adult;

  static Audience parse(Object? value) => switch (value) {
        'adult' => Audience.adult,
        'friends' => Audience.friends,
        _ => Audience.family,
      };
}

/// The vibe chosen on the start screen. Drives which packs are offered,
/// the accent colours and a few lines of copy.
enum PlayContext {
  family(
    label: 'Rodina',
    emoji: '🏡',
    icon: Icons.cottage_rounded,
    tagline: 'V pohodě pro všechny generace',
    audiences: {Audience.family},
    colors: [Color(0xFF16C784), Color(0xFFB8E62E)],
    impostorLine: 'Neznáš slovo. Tvař se nenápadně.',
  ),
  friends(
    label: 'Kamarádi',
    emoji: '😎',
    icon: Icons.groups_rounded,
    tagline: 'Drzejší slova, víc smíchu · 13+',
    audiences: {Audience.family, Audience.friends},
    colors: [Color(0xFFFFB800), Color(0xFFFF6B1A)],
    impostorLine: 'Neznáš slovo. Blafuj, jako by na tom záviselo všechno.',
  ),
  mix(
    label: 'Mix všeho',
    emoji: '🎲',
    icon: Icons.shuffle_rounded,
    tagline: 'Všechno dohromady, i pikantní',
    audiences: {Audience.family, Audience.friends, Audience.adult},
    colors: [Color(0xFFFF3D57), Color(0xFFFFB800)],
    adult: true,
    impostorLine: 'Neznáš slovo. Hraj to s jistotou.',
  ),
  freaky(
    label: 'Freaky',
    emoji: '😈',
    icon: Icons.local_fire_department_rounded,
    tagline: 'Spicy témata jen pro dospělé',
    audiences: {Audience.adult},
    colors: [Color(0xFFFF2E88), Color(0xFF8A2BE2)],
    adult: true,
    impostorLine: 'Neznáš slovo. Svůdně zamlžuj a nenech se chytit.',
  );

  const PlayContext({
    required this.label,
    required this.emoji,
    required this.icon,
    required this.tagline,
    required this.audiences,
    required this.colors,
    required this.impostorLine,
    this.adult = false,
  });

  final String label;
  final String emoji;
  final IconData icon;
  final String tagline;
  final Set<Audience> audiences;
  final List<Color> colors;
  final String impostorLine;

  /// Needs an 18+ confirmation before it can be picked.
  final bool adult;

  Color get accent => colors.first;
  LinearGradient get gradient =>
      LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Audience given to packs created (by hand or AI) while in this context.
  Audience get defaultAudience => switch (this) {
        PlayContext.family => Audience.family,
        PlayContext.freaky => Audience.adult,
        _ => Audience.friends,
      };

  static PlayContext parse(Object? value) =>
      PlayContext.values.firstWhere((c) => c.name == value, orElse: () => PlayContext.friends);
}
