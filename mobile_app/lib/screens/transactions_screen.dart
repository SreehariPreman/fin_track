import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/transaction.dart';
import '../services/bank_profiles.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/imap_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_grouping.dart';
import '../widgets/app_card.dart';
import '../widgets/coming_soon.dart';
import '../widgets/skeleton.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

const _pageSize = 10;

/// The "Transactions" tab: filter chips and the date-grouped transaction
/// list. All list data comes from the local database.
///
/// Fetching is a toolbar action rather than the full-width button it used
/// to be: background sync plus the tap-to-label notification is the normal
/// path in, so a manual pull is a fallback and shouldn't be the loudest
/// thing on the screen.
class TransactionsScreen extends StatefulWidget {
  /// When Home's "Tap to review" is used, RootScreen sets this to
  /// 'unlabelled' and switches to this tab — this screen picks it up and
  /// applies it once, then clears it back to null.
  final ValueNotifier<String?>? pendingFilter;

  const TransactionsScreen({super.key, this.pendingFilter});

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

  /// How many of the (filtered) transactions to actually show — grows by
  /// [_pageSize] each time "Load more" is tapped, rather than rendering
  /// the entire local history (which only grows over time) at once.
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    widget.pendingFilter?.addListener(_onPendingFilter);
    _onPendingFilter();
    _loadFromDb();
  }

  @override
  void dispose() {
    widget.pendingFilter?.removeListener(_onPendingFilter);
    super.dispose();
  }

  void _onPendingFilter() {
    final requested = widget.pendingFilter?.value;
    if (requested == null) return;
    setState(() {
      _filter = requested;
      _visibleCount = _pageSize;
    });
    widget.pendingFilter!.value = null;
  }

  void _selectFilter(String filter) {
    HapticFeedback.selectionClick();
    setState(() {
      _filter = filter;
      _visibleCount = _pageSize;
    });
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
        _error = 'Connect your Gmail account in Settings first.';
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
      if (!mounted) return;
      setState(() => _fetching = false);
    } catch (e) {
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_visibleCount).toList();
    final grouped = groupTransactionsByDate(visible);
    final hasMore = filtered.length > visible.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        titleSpacing: AppTheme.gutter,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.gutter - 8),
            child: _FetchButton(fetching: _fetching, onTap: _fetch),
          ),
        ],
      ),
      body: _loadingList
          ? const ListSkeleton()
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
                children: [
                  if (_error != null) ...[
                    _ErrorPanel(message: _error!),
                    const SizedBox(height: AppTheme.gap),
                  ],
                  if (_transactions.isNotEmpty)
                    _FilterChips(
                      selected: _filter,
                      unlabelledCount: _unlabelledCount,
                      bankCodes: _bankCodes,
                      onSelected: _selectFilter,
                    ),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: ComingSoon(
                        icon: PhosphorIconsRegular.trayArrowDown,
                        message: 'No transactions yet.\nPull down to check your inbox.',
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: ComingSoon(
                        icon: PhosphorIconsRegular.funnel,
                        message: 'Nothing matches this filter.',
                      ),
                    )
                  else
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
                        child: Text(entry.key, style: AppTextStyles.overline),
                      ),
                      TransactionGroupCard(
                        transactions: entry.value,
                        onTap: _openDetail,
                      ),
                    ],
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _visibleCount += _pageSize),
                        child: Text('Show ${filtered.length - visible.length} more'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Toolbar fetch action. Swaps to a spinner in place rather than
/// disappearing, so the button doesn't shift the title while it works.
class _FetchButton extends StatelessWidget {
  final bool fetching;
  final VoidCallback onTap;

  const _FetchButton({required this.fetching, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: fetching ? null : onTap,
      tooltip: 'Fetch from Gmail',
      icon: fetching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : const Icon(PhosphorIconsRegular.arrowsClockwise, size: 21),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return TintedPanel(
      color: AppColors.errorSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsFill.warningCircle, size: 18, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0, duration: 250.ms);
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
      if (unlabelledCount > 0)
        _FilterChipData(value: 'unlabelled', label: 'Unlabelled', count: unlabelledCount),
      for (final code in bankCodes)
        _FilterChipData(value: code, label: bankProfileForCode(code)?.name ?? code),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Let chips run to the screen edge instead of stopping at the
        // page gutter — a row that's clipped mid-chip is the clearest
        // signal that it scrolls.
        padding: const EdgeInsets.only(right: AppTheme.gutter),
        clipBehavior: Clip.none,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final isSelected = chip.value == selected;
          return _Chip(
            data: chip,
            selected: isSelected,
            onTap: () => onSelected(chip.value),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final _FilterChipData data;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                data.label,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (data.count != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${data.count}',
                    style: AppTextStyles.supporting.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipData {
  final String value;
  final String label;
  final int? count;

  const _FilterChipData({required this.value, required this.label, this.count});
}
