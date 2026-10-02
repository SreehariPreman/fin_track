import 'package:flutter/material.dart';

/// The app's single source of truth for color. Light theme only.
///
/// The palette is built on *warm* neutrals rather than the cool blue-greys
/// a default Material app ships with — a warm paper canvas reads as
/// considered rather than generic, and it lets a single saturated accent
/// (jade) carry all the emphasis without competing with the background.
///
/// One surface deliberately breaks the rule: [ink] / [inkElevated] are the
/// near-black gradient used by the hero balance card. That contrast break
/// is what stops every screen from looking like the same white rectangle
/// repeated, so don't reach for it anywhere else.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- brand
  /// Jade. Money-adjacent without being the default fintech blue, and it
  /// holds its own on both the paper canvas and the dark hero card.
  static const primary = Color(0xFF0D7C66);
  static const primaryDark = Color(0xFF0A6252);

  /// 8%-ish tint of [primary], precomputed so tinted fills stay opaque
  /// (stacking translucent fills over the warm canvas muddies the hue).
  static const primarySoft = Color(0xFFE3F1EC);

  // ------------------------------------------------------------- surfaces
  /// Warm paper. The most load-bearing color in the app.
  static const background = Color(0xFFFAF9F7);

  /// Slightly sunken warm neutral — progress-bar tracks, chip rests.
  static const backgroundAlt = Color(0xFFF1EFEA);

  static const card = Color(0xFFFFFFFF);

  /// Near-black, kept for snackbars and scrims. Deliberately *not* the
  /// hero card any more — a black panel in an otherwise light app reads
  /// as "the phone is in dark mode", which was the wrong signal.
  static const ink = Color(0xFF1A1714);
  static const inkElevated = Color(0xFF2E2721);

  /// The hero card's gradient: saturated jade rather than black. It keeps
  /// the contrast break that gives the screen a focal point, while
  /// staying unmistakably a light-theme app.
  static const heroStart = Color(0xFF16745E);
  static const heroEnd = Color(0xFF0B4638);

  // ----------------------------------------------------------------- text
  static const textPrimary = Color(0xFF16130F);
  static const textSecondary = Color(0xFF6B635B);

  /// Darkened from the old #9CA3AF, which sat at 2.4:1 on the canvas and
  /// failed WCAG AA. This clears 4.5:1.
  static const textMuted = Color(0xFF7A716A);

  /// Text sitting on the hero gradient. The muted tone is white at
  /// reduced opacity rather than a grey — a warm grey over jade goes
  /// muddy.
  static const onInk = Color(0xFFFFFFFF);
  static const onInkMuted = Color(0xB3FFFFFF);

  // ------------------------------------------------------------- semantic
  static const success = Color(0xFF2E7D52);
  static const successSoft = Color(0xFFE6F1EA);

  /// Warm ochre rather than a shouty amber — this fires often (every
  /// unlabelled transaction), so it has to be livable.
  static const warning = Color(0xFFC2701C);
  static const warningSoft = Color(0xFFFBF0E2);

  static const error = Color(0xFFB4322C);
  static const errorSoft = Color(0xFFFAEAE8);

  // -------------------------------------------------------------- hairline
  static const border = Color(0xFFE9E5DF);

  /// Two-layer card shadow: a tight contact shadow plus a wide ambient
  /// one. A single blurred shadow is the thing that makes cards look
  /// flat and stickered-on.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(color: Color(0x0A16130F), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x0F16130F), blurRadius: 18, offset: Offset(0, 6)),
      ];

  static List<BoxShadow> get heroShadow => const [
        BoxShadow(color: Color(0x1416130F), blurRadius: 4, offset: Offset(0, 2)),
        BoxShadow(color: Color(0x2616130F), blurRadius: 32, offset: Offset(0, 14)),
      ];
}
