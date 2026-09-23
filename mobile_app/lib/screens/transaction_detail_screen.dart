import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  final UpiTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateStr = transaction.date != null
        ? DateFormat('dd MMM yyyy').format(transaction.date!)
        : 'Unknown date';
    final amountStr = transaction.amount != null
        ? '₹${transaction.amount!.toStringAsFixed(2)}'
        : 'Amount not detected';

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
            const Divider(height: 32),
            Text('Subject', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(transaction.subject),
            const SizedBox(height: 20),
            Text('Full email body', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(transaction.body.isEmpty ? '(empty)' : transaction.body),
          ],
        ),
      ),
    );
  }
}
