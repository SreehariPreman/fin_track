import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/category_colors.dart';

/// Round colored avatar for a category — its first letter on a tint of
/// its deterministic color. Used on transaction cards, the label grid,
/// and the categories list, so a category always looks the same everywhere.
class CategoryAvatar extends StatelessWidget {
  final int categoryId;
  final String name;
  final double size;

  const CategoryAvatar({
    super.key,
    required this.categoryId,
    required this.name,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.forId(categoryId);
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.4),
      ),
    );
  }
}

/// The "needs a label" placeholder avatar, used instead of a category
/// avatar when a transaction hasn't been categorised yet.
class NeedsLabelAvatar extends StatelessWidget {
  final double size;

  const NeedsLabelAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(Icons.priority_high_rounded, color: AppColors.warning, size: size * 0.5),
    );
  }
}
