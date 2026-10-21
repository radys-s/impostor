import 'package:flutter/material.dart';

import '../store/store.dart';

/// Minimal line icons for packs. Packs keep their emoji as a stable key
/// (stored in JSON and custom packs); the UI only ever shows the icon.
abstract final class PackIcons {
  static const fallback = Icons.style_rounded;

  static const Map<String, IconData> _byEmoji = {
    '🍕': Icons.local_pizza_rounded,
    '🐾': Icons.pets_rounded,
    '🐶': Icons.pets_rounded,
    '👷': Icons.engineering_rounded,
    '💼': Icons.work_rounded,
    '⚽': Icons.sports_soccer_rounded,
    '🏰': Icons.castle_rounded,
    '🌍': Icons.public_rounded,
    '🎬': Icons.movie_rounded,
    '⭐': Icons.star_rounded,
    '🎵': Icons.music_note_rounded,
    '🏠': Icons.home_rounded,
    '🍳': Icons.soup_kitchen_rounded,
    '🚗': Icons.directions_car_rounded,
    '🌲': Icons.forest_rounded,
    '🎒': Icons.school_rounded,
    '📚': Icons.menu_book_rounded,
    '👕': Icons.checkroom_rounded,
    '🎄': Icons.celebration_rounded,
    '🇨🇿': Icons.flag_rounded,
    '📺': Icons.live_tv_rounded,
    '💻': Icons.devices_rounded,
    '🎲': Icons.casino_rounded,
    '🎮': Icons.sports_esports_rounded,
    '😂': Icons.sentiment_very_satisfied_rounded,
    '📱': Icons.smartphone_rounded,
    '🙈': Icons.visibility_off_rounded,
    '🫣': Icons.face_retouching_off_rounded,
    '😳': Icons.sentiment_neutral_rounded,
    '🙃': Icons.mood_rounded,
    '🎉': Icons.celebration_rounded,
    '🍻': Icons.sports_bar_rounded,
    '🌃': Icons.nightlife_rounded,
    '🌙': Icons.nightlight_round,
    '💘': Icons.favorite_rounded,
    '❤️': Icons.favorite_rounded,
    '💔': Icons.heart_broken_rounded,
    '🤫': Icons.lock_rounded,
    '🛏️': Icons.bed_rounded,
    '🍑': Icons.sentiment_very_satisfied_rounded,
    '🎭': Icons.theater_comedy_rounded,
    '🔥': Icons.local_fire_department_rounded,
    '🎞️': Icons.theaters_rounded,
    '🎤': Icons.mic_rounded,
    '🧚': Icons.auto_awesome_rounded,
    '✨': Icons.auto_awesome_rounded,
    '🧪': Icons.science_rounded,
    '🧩': Icons.extension_rounded,
  };

  static IconData of(String emoji) =>
      _byEmoji[emoji] ?? _byEmoji[emoji.replaceAll('\uFE0F', '')] ?? _byEmoji['$emoji\uFE0F'] ?? fallback;

  /// Choices offered in the pack editor (emoji keys, shown as icons).
  static const editorChoices = ['🎲', '🍕', '🐾', '🎬', '⚽', '🎵', '🌍', '🏠', '💼', '🚗', '🎮', '🎉', '🌲', '🧪', '📚', '❤️'];
}

/// Icons for round events (keys from roundEvents).
abstract final class EventIcons {
  static const Map<String, IconData> _byKey = {
    'bolt': Icons.bolt_rounded,
    'reverse': Icons.swap_vert_rounded,
    'letter': Icons.abc_rounded,
    'spy': Icons.visibility_rounded,
    'repeat': Icons.repeat_rounded,
    'gesture': Icons.front_hand_rounded,
    'whisper': Icons.hearing_rounded,
    'question': Icons.question_mark_rounded,
    'sound': Icons.graphic_eq_rounded,
    'robot': Icons.smart_toy_rounded,
    'point': Icons.ads_click_rounded,
    'mute': Icons.mic_off_rounded,
    'drama': Icons.theater_comedy_rounded,
    'serious': Icons.sentiment_neutral_rounded,
    'gavel': Icons.gavel_rounded,
    'accent': Icons.record_voice_over_rounded,
    'fire': Icons.local_fire_department_rounded,
    'lips': Icons.mic_external_on_rounded,
    'eyes': Icons.remove_red_eye_rounded,
    'heart': Icons.favorite_rounded,
    'wink': Icons.sentiment_very_satisfied_rounded,
    'drink': Icons.local_bar_rounded,
    'camera': Icons.photo_camera_rounded,
    'shirt': Icons.checkroom_rounded,
    'gift': Icons.redeem_rounded,
  };

  static IconData of(String key) => _byKey[key] ?? Icons.auto_awesome_rounded;
}

extension FeatureIcon on FeaturePlugin {
  IconData get icon => switch (this) {
        FeaturePlugin.scores => Icons.emoji_events_rounded,
        FeaturePlugin.voting => Icons.how_to_vote_rounded,
        FeaturePlugin.ai => Icons.auto_awesome_rounded,
      };
}
