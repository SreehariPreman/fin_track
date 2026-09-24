import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/category_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/coming_soon.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return const ComingSoon(icon: Icons.error_outline, message: 'Could not load analytics.');
    }
    if (_count == 0) {
      return const ComingSoon(icon: Icons.query_stats_outlined, message: 'No transactions in this period.');
    }

    final days = widget.range.span.inDays.clamp(1, 1000);
    final avgPerDay = _total / days;
    double? changePct;
    if (_previousTotal != null && _previousTotal! > 0) {
      changePct = ((_total - _previousTotal!) / _previousTotal!) * 100;
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Spending', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 4),
                Text('₹${_total.toStringAsFixed(0)}', style: AppTextStyles.amountLarge.copyWith(fontSize: 30)),
                if (changePct != null) ...[
                  const SizedBox(height: 6),
                  Row(
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spending trend', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 16),
                SizedBox(height: 140, child: _TrendChart(series: _series)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _KpiCard(value: '$_count', label: 'Transactions')),
              const SizedBox(width: 12),
              Expanded(child: _KpiCard(value: '₹${avgPerDay.toStringAsFixed(0)}', label: 'Avg. per day')),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category distribution', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 16),
                if (_categories.isEmpty)
                  Text('No categorised spending yet.', style: AppTextStyles.bodySecondary)
                else ...[
                  SizedBox(height: 160, child: _CategoryDonut(categories: _categories, total: _total)),
                  const SizedBox(height: 16),
                  for (final c in _categories.take(5)) _CategorySummaryRow(category: c, total: _total),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;

  const _KpiCard({required this.value, required this.label});

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

class _TrendChart extends StatelessWidget {
  final List<DailySpend> series;

  const _TrendChart({required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }
    final spots = [
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].total),
    ];
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
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  final List<CategorySpend> categories;
  final double total;

  const _CategoryDonut({required this.categories, required this.total});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 44,
        sections: [
          for (final c in categories)
            PieChartSectionData(
              value: c.total,
              color: c.categoryId != null ? CategoryColors.forId(c.categoryId!) : AppColors.textMuted,
              radius: 26,
              showTitle: false,
            ),
        ],
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  final CategorySpend category;
  final double total;

  const _CategorySummaryRow({required this.category, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (category.total / total * 100) : 0;
    final color = category.categoryId != null ? CategoryColors.forId(category.categoryId!) : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(category.categoryName, style: AppTextStyles.body)),
          Text('₹${category.total.toStringAsFixed(0)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${pct.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: AppTextStyles.supporting),
          ),
        ],
      ),
    );
  }
}
