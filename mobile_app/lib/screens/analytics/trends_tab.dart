import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/skeleton.dart';

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
    if (_loading) return const AnalyticsSkeleton();
    if (_hasError) {
      return const ComingSoon(icon: PhosphorIconsRegular.warningCircle, message: 'Could not load analytics.');
    }
    if (_daily.isEmpty) {
      return const ComingSoon(icon: PhosphorIconsRegular.chartLineUp, message: 'No transactions in this period.');
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
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
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
                    labelStyle: AppTextStyles.bodySecondary.copyWith(
                      color: _granularity == g ? Colors.white : AppColors.textSecondary,
                      fontWeight: _granularity == g ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _granularity = g);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.gap),
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
            // The shared chart, rather than a second private copy — its
            // label spacing is derived from the series length, which is
            // what stopped the date labels overlapping and running off
            // the right edge here.
            child: SizedBox(height: 200, child: SpendLineChart(series: bucketed)),
          ),
          const SizedBox(height: AppTheme.gap),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: PhosphorIconsRegular.trendUp,
                  value: Money.whole(highest.total),
                  label: 'Highest · ${DateFormat('d MMM').format(highest.date)}',
                ),
              ),
              const SizedBox(width: AppTheme.gap),
              Expanded(
                child: StatTile(
                  icon: PhosphorIconsRegular.chartBar,
                  value: Money.whole(avgDaily),
                  label: 'Avg. per day',
                ),
              ),
            ],
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

