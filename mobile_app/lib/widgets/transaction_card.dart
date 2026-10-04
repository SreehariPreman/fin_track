import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/bank_profiles.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';
import '../utils/money.dart';
import '../utils/text_format.dart';
import 'app_card.dart';
import 'bank_badge.dart';
import 'category_avatar.dart';

/// A date group's transactions as one card of hairline-separated rows.
///
/// Previously every transaction was its own shadowed card. At ten-plus
/// rows that reads as a wall of floating rectangles — one card per day
/// with rows inside restores the grouping the date headers were already
/// implying, and cuts the shadow count from N to one.
class TransactionGroupCard extends StatelessWidget {
  final List<UpiTransaction> transactions;
  final void Function(UpiTransaction) onTap;

  const TransactionGroupCard({
    super.key,
    required this.transactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 70, endIndent: 16),
            TransactionRow(
              transaction: transactions[i],
              onTap: () => onTap(transactions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// One transaction row: category icon, merchant, bank + time, amount, and
/// the category (or a quiet "Needs label" cue).
class TransactionRow extends StatelessWidget {
  final UpiTransaction transaction;
  final VoidCallback onTap;

  const TransactionRow({super.key, required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final timeStr = t.date != null ? DateFormat('h:mm a').format(t.date!) : '';
    final bank = bankProfileForCode(t.bankCode);
    final labelled = t.categoryId != null && t.categoryName != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            labelled
                ? CategoryAvatar(categoryId: t.categoryId!, name: t.categoryName!, size: 40)
                : const NeedsLabelAvatar(size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TextFormat.merchant(t.displayName),
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (bank != null) ...[
                        BankBadge(bank: bank),
                        const SizedBox(width: 7),
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Money.precise(t.amount), style: AppTextStyles.amount),
                const SizedBox(height: 5),
                // Plain coloured text rather than a filled pill. The pill
                // fired on every uncategorised row at once, which made a
                // normal backlog look like a screen full of errors.
                if (labelled)
                  Text(
                    t.categoryName!,
                    style: AppTextStyles.supporting.copyWith(
                      color: CategoryColors.forId(t.categoryId!),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Needs label',
                        style: AppTextStyles.supporting.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tinted pill for a category or status. Used on the detail screen,
/// where exactly one appears at a time.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.supporting.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
