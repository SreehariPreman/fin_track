import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/analytics_filter.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/category_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';
import '../widgets/coming_soon.dart';
import '../widgets/month_selector.dart';

/// Home: greeting, month selector, a Total Spent summary card with a mini
/// trend sparkline, Income/Remaining (currently stubbed — see below), an
/// unlabelled-transactions nudge, and top categories (tapping one jumps to
/// Analytics > Categories, filtered by that category).
///
/// Income/Remaining are placeholders (₹— ) until the parser tracks
/// credit vs debit direction (tracked in the README backlog) — showing a
/// fabricated number here would be more misleading than an honest dash.
class HomeTab extends StatefulWidget {
  final VoidCallback onReviewUnlabelled;

  /// Called with (categoryId, categoryName) when a category row is
  /// tapped — null categoryId means the "Unlabelled" bucket, which has no
  /// analytics filter equivalent, so callers should just switch tabs.
  final void Function(int? categoryId, String categoryName) onCategoryTap;

  /// Whether this tab is the currently-selected one. Home is kept alive in
  /// RootScreen's IndexedStack (so the month selector etc. don't reset
  /// when you switch tabs), which means it otherwise wouldn't notice
  /// changes made elsewhere — e.g. saving your name in Settings, or
  /// fetching/labeling from Transactions — until reopening the app.
  /// Reload whenever this flips back to true.
  final bool active;

  const HomeTab({
    super.key,
    required this.onReviewUnlabelled,
    required this.onCategoryTap,
    required this.active,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _credentialsService = CredentialsService();
  final _analyticsService = AnalyticsService();
  final _db = DatabaseService.instance;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _loading = true;
  bool _hasError = false;
  String? _name;
  double _total = 0;
  double? _previousTotal;
  int _unlabelledCount = 0;
  List<CategorySpend> _categories = [];
  List<DailySpend> _series = [];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  void _shiftMonth(int delta) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final range = DateRange.forMonth(_selectedMonth);
      final name = await _credentialsService.readName();
      final total = await _analyticsService.totalSpend(range, AnalyticsFilter.empty);
      final previousTotal = await _analyticsService.previousMonthTotal(_selectedMonth, AnalyticsFilter.empty);
      final unlabelledCount = await _db.getUnlabelledCount();
      final categories = await _analyticsService.categoryBreakdown(range, AnalyticsFilter.empty);
      final series = await _analyticsService.dailySeries(range, AnalyticsFilter.empty);
      if (!mounted) return;
      setState(() {
        _name = name;
        _total = total;
        _previousTotal = previousTotal;
        _unlabelledCount = unlabelledCount;
        _categories = categories;
        _series = series;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasError) {
      return Scaffold(
        body: SafeArea(
          child: ComingSoon(icon: Icons.error_outline, message: 'Could not load your overview.'),
        ),
      );
    }

    double? changePct;
    if (_previousTotal != null && _previousTotal! > 0) {
      changePct = ((_total - _previousTotal!) / _previousTotal!) * 100;
    }
    final greetingName = (_name != null && _name!.isNotEmpty) ? _name : 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('Hi $greetingName 👋', style: AppTextStyles.screenTitle),
              const SizedBox(height: 4),
              Text("Here's your financial overview", style: AppTextStyles.bodySecondary),
              MonthSelector(
                month: _selectedMonth,
                canGoForward: !_isCurrentMonth,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spent', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 4),
                    Text('₹${_total.toStringAsFixed(0)}', style: AppTextStyles.amountLarge.copyWith(fontSize: 30)),
                    if (changePct != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            changePct >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: changePct >= 0 ? AppColors.error : AppColors.success,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${changePct.abs().toStringAsFixed(0)}% from last month',
                            style: AppTextStyles.supporting.copyWith(
                              color: changePct >= 0 ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_series.length >= 2) ...[
                      const SizedBox(height: 12),
                      SizedBox(height: 48, child: _MiniSparkline(series: _series)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Income', value: '₹—')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Remaining', value: '₹—')),
                ],
              ),
              if (_unlabelledCount > 0) ...[
                const SizedBox(height: 16),
                _UnlabelledAlert(count: _unlabelledCount, onTap: widget.onReviewUnlabelled),
              ],
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spending by Category', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                    const SizedBox(height: 16),
                    if (_categories.isEmpty)
                      Text('No categorised spending this month.', style: AppTextStyles.bodySecondary)
                    else
                      for (final c in _categories.take(5))
                        _CategoryProgressRow(
                          category: c,
                          total: _total,
                          onTap: () => widget.onCategoryTap(c.categoryId, c.categoryName),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.amountLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.supporting),
        ],
      ),
    );
  }
}

class _UnlabelledAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _UnlabelledAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count transaction${count == 1 ? '' : 's'} need labeling',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to review →',
                      style: AppTextStyles.bodySecondary.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  final CategorySpend category;
  final double total;
  final VoidCallback onTap;

  const _CategoryProgressRow({required this.category, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (category.total / total).clamp(0, 1).toDouble() : 0.0;
    final color = category.categoryId != null ? CategoryColors.forId(category.categoryId!) : AppColors.warning;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            category.categoryId != null
                ? CategoryAvatar(categoryId: category.categoryId!, name: category.categoryName, size: 32)
                : const NeedsLabelAvatar(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.categoryName, style: AppTextStyles.body)),
                      Text('₹${category.total.toStringAsFixed(0)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.supporting,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
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

class _MiniSparkline extends StatelessWidget {
  final List<DailySpend> series;

  const _MiniSparkline({required this.series});

  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].total)];
    final maxY = series.map((s) => s.total).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
