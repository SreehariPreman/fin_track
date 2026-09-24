import 'package:flutter/material.dart';

/// The app's single source of truth for color. Light theme only — see the
/// design spec (colors, typography, components) this app follows.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);

  static const background = Color(0xFFF7F9FC);
  static const card = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const border = Color(0xFFE5E7EB);
}
