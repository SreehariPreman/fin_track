import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/category_picker_sheet.dart';

class TransactionDetailScreen extends StatefulWidget {
  final UpiTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _db = DatabaseService.instance;
  late UpiTransaction _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _label() async {
    final category = await CategoryPickerSheet.show(context);
    if (category == null || _transaction.id == null) return;
    await _db.assignCategory(_transaction.id!, category.id);
    setState(() {
      _transaction = _transaction.copyWith(
        categoryId: category.id,
        categoryName: category.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _transaction;
    final dateStr = t.date != null ? DateFormat('dd MMM yyyy · hh:mm a').format(t.date!) : 'Unknown date';
    final amountStr = t.amount != null ? '₹${t.amount!.toStringAsFixed(2)}' : 'Amount not detected';

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(amountStr, style: AppTextStyles.amountLarge),
                  const SizedBox(height: 6),
                  Text(dateStr, style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(
                        avatar: Icon(
                          Icons.label_outline,
                          size: 16,
                          color: t.categoryName == null ? AppColors.textMuted : AppColors.primary,
                        ),
                        label: Text(t.categoryName ?? 'Uncategorised'),
                        backgroundColor: t.categoryName == null
                            ? AppColors.background
                            : AppColors.primary.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: t.categoryName == null ? AppColors.border : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _label,
                        child: Text(t.categoryName == null ? 'Add label' : 'Change label'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(t.subject, style: AppTextStyles.body),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full email body', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    t.body.isEmpty ? '(empty)' : t.body,
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

