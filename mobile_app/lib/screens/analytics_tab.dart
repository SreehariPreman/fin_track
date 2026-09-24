import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_filter.dart';
import '../services/bank_profiles.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'analytics/banks_tab.dart';
import 'analytics/categories_analytics_tab.dart';
import 'analytics/filters_sheet.dart';
import 'analytics/overview_tab.dart';
import 'analytics/trends_tab.dart';

/// Analytics: month selector + Overview/Categories/Banks/Trends sub-tabs,
/// with a Filters sheet whose Date Range (if set) overrides the month
/// selector until reset, and whose Bank/Category/Type selections always
/// apply on top.
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  AnalyticsFilter _filter = AnalyticsFilter.empty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      _filter = _filter.copyWith(clearDateOverride: true);
    });
  }

  Future<void> _openFilters() async {
    final result = await FiltersSheet.show(context, _filter);
    if (result != null) setState(() => _filter = result);
  }

  DateRange get _effectiveRange => _filter.resolveDateRange(_selectedMonth);

  @override
  Widget build(BuildContext context) {
    final range = _effectiveRange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.tune_outlined),
            ),
            onPressed: _openFilters,
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_filter.hasDateOverride) _MonthSelector(
            month: _selectedMonth,
            canGoForward: !_isCurrentMonth,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          if (_filter.activeCount > 0) _ActiveFilterChips(
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: AppTextStyles.supporting.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
            unselectedLabelStyle: AppTextStyles.supporting.copyWith(fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Categories'),
              Tab(text: 'Banks'),
              Tab(text: 'Trends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(range: range, filter: _filter, selectedMonth: _selectedMonth, hasDateOverride: _filter.hasDateOverride),
                CategoriesAnalyticsTab(range: range, filter: _filter),
                BanksTab(range: range, filter: _filter, selectedMonth: _selectedMonth),
                TrendsTab(range: range, filter: _filter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Text(DateFormat('MMMM yyyy').format(month), style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
          IconButton(
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  final AnalyticsFilter filter;
  final ValueChanged<AnalyticsFilter> onChanged;

  const _ActiveFilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (filter.dateRangePreset != null)
            _chip(
              filter.dateRangePreset!.label,
              () => onChanged(filter.copyWith(clearDateOverride: true)),
            ),
          for (final code in filter.bankCodes)
            _chip(
              bankProfileForCode(code)?.name ?? code,
              () => onChanged(filter.copyWith(bankCodes: {...filter.bankCodes}..remove(code))),
            ),
          for (final id in filter.categoryIds)
            FutureBuilder(
              future: db.getCategories(),
              builder: (context, snapshot) {
                final matches = snapshot.data?.where((c) => c.id == id) ?? const [];
                final name = matches.isNotEmpty ? matches.first.name : 'Category';
                return _chip(
                  name,
                  () => onChanged(filter.copyWith(categoryIds: {...filter.categoryIds}..remove(id))),
                );
              },
            ),
          for (final type in filter.transactionTypes)
            _chip(
              type,
              () => onChanged(filter.copyWith(transactionTypes: {...filter.transactionTypes}..remove(type))),
            ),
          if (filter.activeCount > 1)
            TextButton(
              onPressed: () => onChanged(AnalyticsFilter.empty),
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIconColor: AppColors.primary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      side: BorderSide.none,
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
    );
  }
}
