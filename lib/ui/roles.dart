import 'package:flutter/material.dart';

import '../logic/game_engine.dart';
import '../models/play_context.dart';
import '../util/text.dart';
import 'theme.dart';

/// How a secret role looks on its card. Undercover players must look exactly
/// like civilians, so both get the plain word card.
extension RoleLook on PlayerRole {
  /// Big label for special cards, null for the plain word card.
  String? get badge => switch (kind) {
        RoleKind.impostor => 'IMPOSTOR',
        RoleKind.detective => 'DETEKTIV',
        RoleKind.jester => 'ŠAŠEK',
        RoleKind.civilian || RoleKind.undercover => null,
      };

  IconData get icon => switch (kind) {
        RoleKind.impostor => Icons.theater_comedy_rounded,
        RoleKind.detective => Icons.manage_search_rounded,
        RoleKind.jester => Icons.sentiment_very_satisfied_rounded,
        RoleKind.civilian || RoleKind.undercover => Icons.key_rounded,
      };

  LinearGradient? get gradient => switch (kind) {
        RoleKind.impostor => Party.impostor,
        RoleKind.detective => Party.detective,
        RoleKind.jester => Party.jester,
        RoleKind.civilian || RoleKind.undercover => null,
      };

  /// Secret extra lines under the card.
  List<String> secretLines(PlayContext ctx, String packName) => switch (kind) {
        RoleKind.impostor => [
            hint != null ? 'Nápověda: $hint' : ctx.impostorLine,
            if (letter != null) 'Slovo začíná na $letter',
            if (intel.isNotEmpty) '${plural(intel.length, 'Parťák', 'Parťáci', 'Parťáci')}: ${intel.join(', ')}',
          ],
        RoleKind.detective => [
            if (intel.isNotEmpty) '${plural(intel.length, 'Impostor', 'Impostoři', 'Impostoři')}: ${intel.join(', ')}',
            'Naveď ostatní, ale nenech se prozradit.',
          ],
        RoleKind.jester => ['Tvař se podezřele. Když tě vyhlasují, vyhráváš sám.'],
        RoleKind.civilian || RoleKind.undercover => ['Téma: $packName'],
      };
}
