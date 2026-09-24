import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';
import 'label_transaction_screen.dart';
import 'original_email_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final UpiTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _db = DatabaseService.instance;
  late UpiTransaction _transaction;
  late TextEditingController _notesController;
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _notesController = TextEditingController(text: _transaction.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openLabelScreen() async {
    if (_transaction.id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LabelTransactionScreen(transaction: _transaction)),
    );
    if (changed == true) {
      final refreshed = (await _db.getAllTransactions())
          .where((t) => t.id == _transaction.id)
          .cast<UpiTransaction?>()
          .firstWhere((t) => t != null, orElse: () => null);
      if (refreshed != null && mounted) {
        setState(() {
          _transaction = refreshed;
          _notesController.text = refreshed.notes ?? '';
        });
      }
    }
  }

  Future<void> _saveNotes() async {
    if (_transaction.id == null) return;
    await _db.updateNotes(_transaction.id!, _notesController.text.trim());
    setState(() {
      _transaction = _transaction.copyWith(notes: _notesController.text.trim());
      _editingNotes = false;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This removes it from your local history. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || _transaction.id == null) return;
    await _db.deleteTransaction(_transaction.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _transaction;
    final dateStr = t.date != null ? DateFormat('dd MMM yyyy · h:mm a').format(t.date!) : 'Unknown date';
    final amountStr = t.amount != null ? '₹${t.amount!.toStringAsFixed(2)}' : 'Amount not detected';

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero
            Column(
              children: [
                t.categoryId != null
                    ? CategoryAvatar(categoryId: t.categoryId!, name: t.categoryName ?? '?', size: 64)
                    : const NeedsLabelAvatar(size: 64),
                const SizedBox(height: 12),
                Text(t.displayName, style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(amountStr, style: AppTextStyles.amountLarge.copyWith(fontSize: 30)),
                const SizedBox(height: 4),
                Text(dateStr, style: AppTextStyles.bodySecondary),
              ],
            ),
            const SizedBox(height: 24),

            // Details card
            AppCard(
              child: Column(
                children: [
                  _DetailRow(label: 'Bank', value: t.bankName),
                  _DetailRow(label: 'UPI ID', value: t.upiId),
                  _DetailRow(label: 'Reference No.', value: t.referenceNo),
                  _DetailRow(label: 'Transaction Type', value: t.transactionType),
                  _DetailRow(label: 'Status', value: t.status, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OriginalEmailScreen(subject: t.subject, body: t.body),
                ),
              ),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('View Original Email'),
            ),
            const SizedBox(height: 16),

            // Category
            AppCard(
              onTap: _openLabelScreen,
              child: Row(
                children: [
                  Text('Category', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                  const Spacer(),
                  Text(
                    t.categoryName ?? 'Needs Label',
                    style: AppTextStyles.body.copyWith(
                      color: t.categoryName == null ? AppColors.warning : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_editingNotes)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          autofocus: true,
                          decoration: const InputDecoration(hintText: 'Add a note'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(onPressed: _saveNotes, child: const Text('Save')),
                        ),
                      ],
                    )
                  else if ((t.notes ?? '').isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _editingNotes = true),
                      child: Text(t.notes!, style: AppTextStyles.bodySecondary),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _editingNotes = true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Note'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Destructive action, visually separated
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                label: Text('Delete Transaction', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLast;

  const _DetailRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          Expanded(
            flex: 2,
            child: Text(
              value!,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
