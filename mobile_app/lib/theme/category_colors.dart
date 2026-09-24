import 'package:flutter/material.dart';

/// Categories are entirely user-created (no fixed set), so there's no
/// curated icon per category. Instead each category gets a deterministic
/// color from this palette (by id) and shows as an initial-letter avatar
/// — consistent everywhere (transaction cards, label grid, settings)
/// without the user ever having to pick a color or icon.
class CategoryColors {
  CategoryColors._();

  static const List<Color> _palette = [
    Color(0xFF2563EB), // blue
    Color(0xFF16A34A), // green
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF9333EA), // purple
    Color(0xFF0D9488), // teal
    Color(0xFFDB2777), // pink
    Color(0xFFCA8A04), // yellow/gold
    Color(0xFF4F46E5), // indigo
    Color(0xFFEA580C), // orange
  ];

  static Color forId(int id) => _palette[id % _palette.length];
}
