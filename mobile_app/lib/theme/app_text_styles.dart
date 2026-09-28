import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography. Manrope throughout — it has more character than Inter at
/// display sizes while staying just as legible in a dense list.
///
/// Two rules worth keeping:
///  * Anything showing currency uses [_tabular], so digits occupy equal
///    width and amounts line up as a column instead of jittering.
///  * Large text gets negative tracking. Default letter spacing at 44px
///    is what makes big numbers look like a web page rather than an app.
class AppTextStyles {
  AppTextStyles._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle get _base => GoogleFonts.manrope(color: AppColors.textPrimary);

  // ------------------------------------------------------------- display
  /// The hero balance. Deliberately much larger than anything else on the
  /// screen — the whole layout hangs off this one number.
  static TextStyle get display => _base.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -1.6,
        fontFeatures: _tabular,
      );

  static TextStyle get screenTitle => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.6,
      );

  static TextStyle get sectionTitle => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      );

  /// All-caps micro label above a group ("THIS MONTH"). Tracking is
  /// positive here — small caps need air to stay readable.
  static TextStyle get overline => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.9,
        color: AppColors.textMuted,
      );

  // -------------------------------------------------------------- amounts
  static TextStyle get amountLarge => _base.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
        fontFeatures: _tabular,
      );

  /// Row-level amount, e.g. in a transaction card or category list.
  static TextStyle get amount => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        fontFeatures: _tabular,
      );

  // ----------------------------------------------------------------- body
  static TextStyle get body =>
      _base.copyWith(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500);

  static TextStyle get bodySecondary => _base.copyWith(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get supporting => _base.copyWith(
        fontSize: 12.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      );
}
