import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../theme/category_colors.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';

class OverviewTab extends StatefulWidget {
  final DateRange range;
  final AnalyticsFilter filter;
  final DateTime selectedMonth;
  final bool hasDateOverride;

  const OverviewTab({
    super.key,
    required this.range,
    required this.filter,
    required this.selectedMonth,
    required this.hasDateOverride,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final _service = AnalyticsService();

  bool _loading = true;
  bool _hasError = false;
  double _total = 0;
  double? _previousTotal;
  int _count = 0;
  List<DailySpend> _series = [];
  List<CategorySpend> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OverviewTab old) {
    super.didUpdateWidget(old);
    if (old.range.start != widget.range.start ||
        old.range.end != widget.range.end ||
        old.filter != widget.filter) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final total = await _service.totalSpend(widget.range, widget.filter);
      final count = await _service.transactionCount(widget.range, widget.filter);
      final series = await _service.dailySeries(widget.range, widget.filter);
      final categories = await _service.categoryBreakdown(widget.range, widget.filter);
      double? previousTotal;
      if (!widget.hasDateOverride) {
        previousTotal = await _service.previousMonthTotal(widget.selectedMonth, widget.filter);
      }
      if (!mounted) return;
      setState(() {
        _total = total;
        _count = count;
        _series = series;
        _categories = categories;
        _previousTotal = previousTotal;
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

  /// Unlabelled is amber everywhere else in the app (the needs-label
  /// avatar, Home's category rows), so it's amber here too. It was a
  /// heavy neutral grey, which made the single largest slice read as
  /// dead space rather than as the backlog it is.
  Color _colorFor(CategorySpend c) =>
      c.categoryId != null ? CategoryColors.forId(c.categoryId!) : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AnalyticsSkeleton();
    if (_hasError) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.warningCircle,
        message: 'Could not load analytics.',
      );
    }
    if (_count == 0) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.chartLineUp,
        message: 'No transactions in this period.',
      );
    }

    final days = widget.range.span.inDays.clamp(1, 1000);
    final avgPerDay = _total / days;
    double? changePct;
    if (_previousTotal != null && _previousTotal! > 0) {
      changePct = ((_total - _previousTotal!) / _previousTotal!) * 100;
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SPENDING', style: AppTextStyles.overline),
                const SizedBox(height: 10),
                Text(Money.whole(_total), style: AppTextStyles.display.copyWith(fontSize: 36)),
                if (changePct != null) ...[
                  const SizedBox(height: 12),
                  _DeltaPill(changePct: changePct),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: PhosphorIconsRegular.receipt,
                  value: '$_count',
                  label: _count == 1 ? 'Transaction' : 'Transactions',
                ),
              ),
              const SizedBox(width: AppTheme.gap),
              Expanded(
                child: StatTile(
                  icon: PhosphorIconsRegular.chartBar,
                  value: Money.whole(avgPerDay),
                  label: 'Avg. per day',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Spending trend'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
            child: SizedBox(height: 180, child: SpendLineChart(series: _series)),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Where it went'),
          AppCard(
            child: _categories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No categorised spending yet.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 190,
                        child: DonutChart(
                          total: _total,
                          slices: [
                            for (final c in _categories)
                              DonutSlice(
                                label: c.categoryName,
                                value: c.total,
                                color: _colorFor(c),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      for (final c in _categories.take(6))
                        ChartLegendRow(
                          color: _colorFor(c),
                          label: c.categoryName,
                          value: c.total,
                          total: _total,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double changePct;

  const _DeltaPill({required this.changePct});

  @override
  Widget build(BuildContext context) {
    // Spending more is the bad direction, so "up" is warm, not green.
    final up = changePct >= 0;
    final color = up ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
      decoration: BoxDecoration(
        color: up ? AppColors.warningSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? PhosphorIconsBold.arrowUpRight : PhosphorIconsBold.arrowDownRight,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '${changePct.abs().toStringAsFixed(0)}% vs last month',
            style: AppTextStyles.supporting.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
