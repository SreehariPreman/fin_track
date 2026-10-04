import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../models/analytics_filter.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/transaction_grouping.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/transaction_card.dart';
import '../transaction_detail_screen.dart';

/// Transactions for one category within a date range — reached by tapping
/// a row on the Analytics Categories tab. Same date-grouped card list
/// design as the Transactions tab, just pre-filtered to this category.
class CategoryTransactionsScreen extends StatefulWidget {
  final int? categoryId; // null = the "Unlabelled" bucket
  final String categoryName;
  final DateRange range;
  final AnalyticsFilter filter;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.range,
    required this.filter,
  });

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  bool _hasError = false;
  List<UpiTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final rows = await _db.getTransactionsForCategory(
        start: widget.range.start,
        end: widget.range.end,
        categoryId: widget.categoryId,
        bankCodes: widget.filter.bankCodes,
        transactionTypes: widget.filter.transactionTypes,
      );
      if (!mounted) return;
      setState(() {
        _transactions = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _openDetail(UpiTransaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupTransactionsByDate(_transactions);

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _loading
          ? const ListSkeleton()
          : _hasError
              ? const ComingSoon(icon: PhosphorIconsRegular.warningCircle, message: 'Could not load transactions.')
              : _transactions.isEmpty
                  ? const ComingSoon(
                      icon: PhosphorIconsRegular.trayArrowDown,
                      message: 'No transactions for this category in this period.',
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                              child: Text(entry.key, style: AppTextStyles.sectionTitle.copyWith(fontSize: 14)),
                            ),
                            ...entry.value.map(
                              (t) => TransactionRow(transaction: t, onTap: () => _openDetail(t)),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
