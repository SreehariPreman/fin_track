import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared placeholder body for tabs that aren't built yet.
class ComingSoon extends StatelessWidget {
  final IconData icon;
  final String message;

  const ComingSoon({super.key, required this.icon, this.message = 'Coming soon'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}
