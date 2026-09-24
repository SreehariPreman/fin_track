import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography hierarchy per the design spec. Amounts get their own style
/// distinct from generic "screen title" so currency always reads as the
/// most prominent thing on a card, ahead of any label describing it.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(color: AppColors.textPrimary);

  static TextStyle get screenTitle =>
      _base.copyWith(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2);

  static TextStyle get sectionTitle =>
      _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get amountLarge =>
      _base.copyWith(fontSize: 26, fontWeight: FontWeight.bold, height: 1.1);

  static TextStyle get body => _base.copyWith(fontSize: 15, height: 1.4);

  static TextStyle get bodySecondary =>
      _base.copyWith(fontSize: 14, height: 1.4, color: AppColors.textSecondary);

  static TextStyle get supporting =>
      _base.copyWith(fontSize: 12.5, height: 1.3, color: AppColors.textMuted);
}
