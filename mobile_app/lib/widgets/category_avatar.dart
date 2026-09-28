import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/category_colors.dart';

/// Rounded-square icon tile for a category — an icon guessed from the
/// category's name, on a tint of its deterministic color.
///
/// This replaced a first-letter avatar. "B" on a green circle carried no
/// information; a bowl of food scans instantly in a list, which matters
/// most exactly where the list is long.
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
    return _IconTile(
      size: size,
      color: color,
      icon: CategoryIcons.forName(name),
    );
  }
}

/// The "needs a label" placeholder, used where a category avatar would go
/// on an uncategorised transaction.
class NeedsLabelAvatar extends StatelessWidget {
  final double size;

  const NeedsLabelAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return _IconTile(
      size: size,
      color: AppColors.warning,
      icon: PhosphorIconsRegular.question,
    );
  }
}

class _IconTile extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;

  const _IconTile({required this.size, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        // Squircle rather than a circle: it echoes the card radius, and
        // circles everywhere is what makes an app read as a contact list.
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
