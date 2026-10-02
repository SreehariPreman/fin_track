import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// Small paired metric card ("17 / Transactions").
///
/// Value first and label second, at a big size delta — reversing that
/// (label above a value) is what made the old Income/Remaining tiles read
/// as form fields rather than statistics.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;

  const StatTile({super.key, required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: AppColors.textMuted),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            style: AppTextStyles.amountLarge.copyWith(fontSize: 23),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.supporting),
        ],
      ),
    );
  }
}
