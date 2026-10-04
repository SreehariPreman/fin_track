import 'package:flutter/material.dart';

import '../services/bank_profiles.dart';
import '../theme/app_text_styles.dart';

/// Small monogram chip standing in for a bank logo (no trademarked logo
/// assets are embedded) — e.g. "HDFC".
///
/// Tinted rather than filled: a solid navy or maroon block repeated down
/// every row of the list pulled far more attention than the bank deserves
/// next to the merchant and the amount.
class BankBadge extends StatelessWidget {
  final BankProfile bank;

  const BankBadge({super.key, required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bank.badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        bank.code,
        style: AppTextStyles.supporting.copyWith(
          color: bank.badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
