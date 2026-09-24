import 'package:flutter/material.dart';

import '../services/bank_profiles.dart';

/// Small colored monogram chip standing in for a bank logo (no trademarked
/// logo assets are embedded) — e.g. "HDFC" on a navy chip.
class BankBadge extends StatelessWidget {
  final BankProfile bank;
  final double fontSize;

  const BankBadge({super.key, required this.bank, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bank.badgeColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        bank.code,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
