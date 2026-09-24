import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/bank_profiles.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/imap_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/bank_badge.dart';
import '../widgets/category_avatar.dart';
import '../widgets/coming_soon.dart';
import 'transaction_detail_screen.dart';

/// The "Transactions" tab: fetch button, filter chips, and the date-grouped
/// transaction list. All list data comes from the local database — Fetch
/// just pulls new mail into it.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _credentialsService = CredentialsService();
  final _imapService = ImapService();
  final _db = DatabaseService.instance;

  List<UpiTransaction> _transactions = [];
  List<String> _bankCodes = [];
  int _unlabelledCount = 0;
  bool _fetching = false;
  bool _loadingList = true;
  String? _error;

  /// 'all', 'unlabelled', or a bank code (e.g. 'HDFC').
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final rows = await _db.getAllTransactions();
      final banks = await _db.getDistinctBankCodes();
      final unlabelled = await _db.getUnlabelledCount();
      if (!mounted) return;
      setState(() {
        _transactions = rows;
        _bankCodes = banks;
        _unlabelledCount = unlabelled;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = 'Could not load local database: $e';
      });
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _error = null;
    });

    final email = await _credentialsService.readEmail();
    final passcode = await _credentialsService.readAppPasscode();

    if (email == null || email.isEmpty || passcode == null || passcode.isEmpty) {
      setState(() {
        _fetching = false;
        _error = 'Set your email and app passcode in Settings first.';
      });
      return;
    }

    try {
      final fetched = await _imapService.fetchLastUpiTransactions(
        email: email,
        appPasscode: passcode,
        maxCount: 10,
      );
      await _db.insertNewTransactions(fetched);
      await _loadFromDb();
      setState(() => _fetching = false);
    } catch (e) {
      setState(() {
        _fetching = false;
        _error = 'Could not fetch mail: $e';
      });
    }
  }

  Future<void> _openDetail(UpiTransaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
    );
    // The detail screen may have changed this transaction's label.
    _loadFromDb();
  }

  List<UpiTransaction> get _filtered {
    switch (_filter) {
      case 'unlabelled':
        return _transactions.where((t) => t.categoryId == null).toList();
      case 'all':
        return _transactions;
      default:
        return _transactions.where((t) => t.bankCode == _filter).toList();
    }
  }

  /// Groups (already date-descending) transactions under "Today"/"Yesterday"/
  /// date headers, preserving order.
  Map<String, List<UpiTransaction>> get _grouped {
    final groups = <String, List<UpiTransaction>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final t in _filtered) {
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

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetch,
        child: _loadingList
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  FilledButton.icon(
                    onPressed: _fetching ? null : _fetch,
                    icon: _fetching
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(_fetching ? 'Fetching...' : 'Fetch last 10 UPI transactions'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
                      ),
                    ),
                  if (_transactions.isNotEmpty) ...[
                    _FilterChips(
                      selected: _filter,
                      unlabelledCount: _unlabelledCount,
                      bankCodes: _bankCodes,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: ComingSoon(
                        icon: Icons.inbox_outlined,
                        message: 'No transactions yet. Tap Fetch to load your inbox.',
                      ),
                    )
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: ComingSoon(
                        icon: Icons.filter_alt_off_outlined,
                        message: 'No transactions match this filter.',
                      ),
                    )
                  else
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Text(entry.key, style: AppTextStyles.sectionTitle.copyWith(fontSize: 14)),
                      ),
                      ...entry.value.map(
                        (t) => _TransactionCard(transaction: t, onTap: () => _openDetail(t)),
                      ),
                    ],
                ],
              ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final int unlabelledCount;
  final List<String> bankCodes;
  final ValueChanged<String> onSelected;

  const _FilterChips({
    required this.selected,
    required this.unlabelledCount,
    required this.bankCodes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_FilterChipData>[
      const _FilterChipData(value: 'all', label: 'All'),
      _FilterChipData(value: 'unlabelled', label: 'Unlabelled ($unlabelledCount)'),
      for (final code in bankCodes)
        _FilterChipData(value: code, label: bankProfileForCode(code)?.name ?? code),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final isSelected = chip.value == selected;
          return ChoiceChip(
            label: Text(chip.label),
            selected: isSelected,
            onSelected: (_) => onSelected(chip.value),
            showCheckmark: false,
            labelStyle: AppTextStyles.bodySecondary.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            backgroundColor: AppColors.card,
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border),
          );
        },
      ),
    );
  }
}

class _FilterChipData {
  final String value;
  final String label;

  const _FilterChipData({required this.value, required this.label});
}

class _TransactionCard extends StatelessWidget {
  final UpiTransaction transaction;
  final VoidCallback onTap;

  const _TransactionCard({required this.transaction, required this.onTap});

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
                  _Pill(
                    label: t.categoryName!,
                    color: CategoryColors.forId(t.categoryId!),
                  )
                else
                  const _Pill(label: 'Needs Label', color: AppColors.warning, icon: Icons.warning_amber_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Pill({required this.label, required this.color, this.icon});

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
