import 'package:intl/intl.dart';

import '../models/transaction.dart';

/// Groups (already date-descending) transactions under "Today"/"Yesterday"/
/// date headers, preserving order. Shared by Transactions and the
/// category-drilldown screen so both group identically.
Map<String, List<UpiTransaction>> groupTransactionsByDate(List<UpiTransaction> transactions) {
  final groups = <String, List<UpiTransaction>>{};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  for (final t in transactions) {
    String header;
    if (t.date == null) {
      header = 'Date unknown';
    } else {
      final d = DateTime(t.date!.year, t.date!.month, t.date!.day);
      final dateStr = DateFormat('dd MMM yyyy').format(t.date!);
      if (d == today) {
        header = 'Today · $dateStr';
      } else if (d == yesterday) {
        header = 'Yesterday · $dateStr';
      } else {
        header = dateStr;
      }
    }
    groups.putIfAbsent(header, () => []).add(t);
  }
  return groups;
}
