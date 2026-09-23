import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(amountStr, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: Text(t.categoryName ?? 'Uncategorised'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _label,
                  child: Text(t.categoryName == null ? 'Add label' : 'Change label'),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Subject', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(t.subject),
            const SizedBox(height: 20),
            Text('Full email body', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(t.body.isEmpty ? '(empty)' : t.body),
          ],
        ),
      ),
    );
  }
}
