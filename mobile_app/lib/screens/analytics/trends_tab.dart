import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/coming_soon.dart';

enum _Granularity { daily, weekly, monthly }

/// Time-based spending — Daily/Weekly/Monthly toggle over a line chart,
/// plus highest-spending-day and average-daily-spending stats (always
/// computed at day granularity regardless of the chart's toggle).
class TrendsTab extends StatefulWidget {
  final DateRange range;
  final AnalyticsFilter filter;

  const TrendsTab({super.key, required this.range, required this.filter});

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab> {
  final _service = AnalyticsService();
  bool _loading = true;
  bool _hasError = false;
  List<DailySpend> _daily = [];
  _Granularity _granularity = _Granularity.daily;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrendsTab old) {
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
      final daily = await _service.dailySeries(widget.range, widget.filter);
      if (!mounted) return;
      setState(() {
        _daily = daily;
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

  List<DailySpend> get _bucketed {
    switch (_granularity) {
      case _Granularity.daily:
        return _daily;
      case _Granularity.weekly:
        return _bucketBy(_daily, (d) {
          final weekday = d.weekday;
          return d.subtract(Duration(days: weekday - 1));
        });
      case _Granularity.monthly:
        return _bucketBy(_daily, (d) => DateTime(d.year, d.month, 1));
    }
  }

  List<DailySpend> _bucketBy(List<DailySpend> series, DateTime Function(DateTime) keyOf) {
    final buckets = <DateTime, double>{};
    for (final s in series) {
      final key = keyOf(s.date);
      buckets[key] = (buckets[key] ?? 0) + s.total;
    }
    final keys = buckets.keys.toList()..sort();
    return [for (final k in keys) DailySpend(date: k, total: buckets[k]!)];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return const ComingSoon(icon: Icons.error_outline, message: 'Could not load analytics.');
    }
    if (_daily.isEmpty) {
      return const ComingSoon(icon: Icons.show_chart, message: 'No transactions in this period.');
    }

    final total = _daily.fold<double>(0, (sum, d) => sum + d.total);
    final days = widget.range.span.inDays.clamp(1, 1000);
    final avgDaily = total / days;
    final highest = _daily.reduce((a, b) => a.total >= b.total ? a : b);
    final bucketed = _bucketed;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              for (final g in _Granularity.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_label(g)),
                    selected: _granularity == g,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _granularity = g),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: SizedBox(height: 200, child: _TrendLineChart(series: bucketed, granularity: _granularity)),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Highest Spending Day', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM').format(highest.date)} · ₹${highest.total.toStringAsFixed(0)}',
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average Daily Spending', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 4),
                Text('₹${avgDaily.toStringAsFixed(0)}', style: AppTextStyles.sectionTitle.copyWith(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(_Granularity g) => switch (g) {
        _Granularity.daily => 'Daily',
        _Granularity.weekly => 'Weekly',
        _Granularity.monthly => 'Monthly',
      };
}

class _TrendLineChart extends StatelessWidget {
  final List<DailySpend> series;
  final _Granularity granularity;

  const _TrendLineChart({required this.series, required this.granularity});

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }
    final spots = [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].total)];
    final maxY = series.map((s) => s.total).reduce((a, b) => a > b ? a : b);
    final dateFormat = granularity == _Granularity.monthly ? DateFormat('MMM') : DateFormat('dd MMM');

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (series.length / 4).clamp(1, series.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dateFormat.format(series[i].date), style: AppTextStyles.supporting),
                );
              },
            ),
          ),
        ),
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
