import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/bank_profiles.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';
import 'app_card.dart';
import 'bank_badge.dart';
import 'category_avatar.dart';

/// The one transaction list-row design — used on the Transactions tab and
/// Home's Recent Transactions. Avatar (category color, or a "needs a
/// label" warning avatar), name, bank badge + time, amount, category pill.
class TransactionCard extends StatelessWidget {
  final UpiTransaction transaction;
  final VoidCallback onTap;

  const TransactionCard({super.key, required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final timeStr = t.date != null ? DateFormat('h:mm a').format(t.date!) : '';
    final bank = bankProfileForCode(t.bankCode);
    final amountStr = t.amount != null ? '₹${t.amount!.toStringAsFixed(2)}' : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            t.categoryId != null
                ? CategoryAvatar(categoryId: t.categoryId!, name: t.categoryName ?? '?')
                : const NeedsLabelAvatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.displayName,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bank != null) ...[
                        BankBadge(bank: bank),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          timeStr,
                          style: AppTextStyles.supporting,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amountStr, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (t.categoryId != null && t.categoryName != null)
                  StatusPill(
                    label: t.categoryName!,
                    color: CategoryColors.forId(t.categoryId!),
                  )
                else
                  const StatusPill(label: 'Needs Label', color: AppColors.warning, icon: Icons.warning_amber_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored pill used for a category label or status (e.g. "Needs Label").
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
