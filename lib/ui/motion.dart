import 'package:flutter/widgets.dart';

/// Single source of truth for motion. Every animation in the app uses these.
abstract final class Motion {
  /// Press feedback.
  static const instant = Duration(milliseconds: 120);

  /// Small state changes, exits.
  static const quick = Duration(milliseconds: 280);

  /// Standard element entrance.
  static const base = Duration(milliseconds: 450);

  /// Larger blocks, card flip.
  static const slow = Duration(milliseconds: 700);

  /// Hero moments, once per screen.
  static const cinematic = Duration(milliseconds: 1100);

  /// Gap between siblings in a staggered group.
  static const stagger = Duration(milliseconds: 70);

  /// Fast start, calm landing. Same as CSS cubic-bezier(.22, 1, .36, 1).
  static const ease = Cubic(0.22, 1, 0.36, 1);

  /// Playful overshoot for selections and pops.
  static const pop = Curves.easeOutBack;

  /// true when the OS asks for reduced motion: animations then jump to the end state.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
