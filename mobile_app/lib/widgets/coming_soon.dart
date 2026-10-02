import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared empty/error state: a soft icon tile above a short message.
///
/// The icon sits on a neutral tint rather than the brand colour — an
/// empty list isn't an achievement, and a jade badge made "nothing here"
/// read like a success confirmation.
class ComingSoon extends StatelessWidget {
  final IconData icon;
  final String message;

  const ComingSoon({super.key, required this.icon, this.message = 'Coming soon'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}
