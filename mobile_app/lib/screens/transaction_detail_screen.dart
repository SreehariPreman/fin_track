import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/text_format.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';
import '../widgets/section_header.dart';
import 'label_transaction_screen.dart';
import 'original_email_screen.dart';

/// One transaction in full: a centred hero (icon, payee, amount, date),
/// the parsed fields, its category, and notes.
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
        content: const Text(
          "This removes it from your local history. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
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
    final dateStr = t.date != null
        ? DateFormat('dd MMM yyyy · h:mm a').format(t.date!)
        : 'Date unknown';
    final labelled = t.categoryId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
        actions: [
          IconButton(
            onPressed: _delete,
            tooltip: 'Delete transaction',
            icon: const Icon(PhosphorIconsRegular.trashSimple, size: 20),
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppTheme.gutter - 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 8, AppTheme.gutter, AppTheme.sectionGap),
        children: [
          _Hero(transaction: t, dateStr: dateStr),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Details'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                _DetailRow(label: 'Bank', value: t.bankName),
                _DetailRow(label: 'UPI ID', value: t.upiId),
                _DetailRow(label: 'Reference', value: t.referenceNo),
                _DetailRow(label: 'Type', value: t.transactionType),
                _DetailRow(label: 'Status', value: t.status),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          AppCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OriginalEmailScreen(subject: t.subject, body: t.body),
              ),
            ),
            child: const _NavRow(
              icon: PhosphorIconsRegular.envelopeSimple,
              label: 'View original email',
            ),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Category'),
          AppCard(
            padding: EdgeInsets.zero,
            onTap: _openLabelScreen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  labelled
                      ? CategoryAvatar(
                          categoryId: t.categoryId!,
                          name: t.categoryName ?? '?',
                          size: 38,
                        )
                      : const NeedsLabelAvatar(size: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t.categoryName ?? 'Needs a label',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: labelled ? AppColors.textPrimary : AppColors.warning,
                      ),
                    ),
                  ),
                  Text(
                    labelled ? 'Change' : 'Add',
                    style: AppTextStyles.supporting.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    PhosphorIconsBold.caretRight,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Notes'),
          AppCard(
            child: _editingNotes
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Add a note',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _saveNotes,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () => setState(() => _editingNotes = true),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (t.notes ?? '').isNotEmpty ? t.notes! : 'Add a note',
                            style: (t.notes ?? '').isNotEmpty
                                ? AppTextStyles.body
                                : AppTextStyles.bodySecondary
                                    .copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        const Icon(
                          PhosphorIconsRegular.notePencil,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final UpiTransaction transaction;
  final String dateStr;

  const _Hero({required this.transaction, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return Column(
      children: [
        t.categoryId != null
            ? CategoryAvatar(categoryId: t.categoryId!, name: t.categoryName ?? '?', size: 64)
            : const NeedsLabelAvatar(size: 64),
        const SizedBox(height: 16),
        Text(
          TextFormat.merchant(t.displayName),
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          t.amount != null ? Money.precise(t.amount) : 'Amount not detected',
          style: t.amount != null
              ? AppTextStyles.display.copyWith(fontSize: 38)
              : AppTextStyles.sectionTitle.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(dateStr, style: AppTextStyles.supporting),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NavRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight, size: 12, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: SelectableText(
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
