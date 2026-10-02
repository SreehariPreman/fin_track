import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../services/bank_profiles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';

/// Spending split by bank: a donut with the split, a month-over-month
/// comparison, and a per-bank daily trend.
///
/// Bank colours here are each bank's own badge colour, deliberately — it's
/// what makes a slice recognisable as the same "HDFC" you see on every
/// transaction row, so the chart and the list agree.
class BanksTab extends StatefulWidget {
  final DateRange range;
  final AnalyticsFilter filter;
  final DateTime selectedMonth;

  const BanksTab({
    super.key,
    required this.range,
    required this.filter,
    required this.selectedMonth,
  });

  @override
  State<BanksTab> createState() => _BanksTabState();
}

class _BanksTabState extends State<BanksTab> {
  final _service = AnalyticsService();
  bool _loading = true;
  bool _hasError = false;
  List<BankSpend> _banks = [];
  Map<String, List<MonthlySpend>> _monthly = {};
  Map<String, List<DailySpend>> _dailyPerBank = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BanksTab old) {
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
      final banks = await _service.bankBreakdown(widget.range, widget.filter);
      final monthly = await _service.monthlyTotalsPerBank(widget.selectedMonth, 6, widget.filter);
      final daily = await _service.dailySeriesPerBank(widget.range, widget.filter);
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _monthly = monthly;
        _dailyPerBank = daily;
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

  Color _colorFor(String bankCode) =>
      bankProfileForCode(bankCode)?.badgeColor ?? AppColors.textMuted;

  String _nameFor(String bankCode) =>
      bankProfileForCode(bankCode)?.name ?? bankCode;

  /// Months that actually carry a figure for at least one bank, in order.
  List<DateTime> get _monthsWithData {
    final months = <DateTime>{};
    for (final series in _monthly.values) {
      for (final m in series) {
        if (m.total > 0) months.add(DateTime(m.month.year, m.month.month));
      }
    }
    final sorted = months.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AnalyticsSkeleton();
    if (_hasError) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.warningCircle,
        message: 'Could not load analytics.',
      );
    }
    if (_banks.isEmpty) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.bank,
        message: 'No transactions in this period.',
      );
    }

    final total = _banks.fold<double>(0, (sum, b) => sum + b.total);
    final months = _monthsWithData;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
        children: [
          const SectionHeader(title: 'Split by bank'),
          AppCard(
            child: Column(
              children: [
                SizedBox(
                  height: 190,
                  child: DonutChart(
                    total: total,
                    slices: [
                      for (final b in _banks)
                        DonutSlice(
                          label: b.bankName,
                          value: b.total,
                          color: _colorFor(b.bankCode),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final b in _banks)
                  ChartLegendRow(
                    color: _colorFor(b.bankCode),
                    label: b.bankName,
                    value: b.total,
                    total: total,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Month over month'),
          AppCard(
            // Chart padding is asymmetric to make room for the axis
            // labels; the placeholder has no axes, so it gets even
            // padding and only the height its one line needs.
            padding: months.length < 2
                ? const EdgeInsets.symmetric(horizontal: 24, vertical: 26)
                : const EdgeInsets.fromLTRB(10, 20, 20, 14),
            // With a single month there is nothing to compare, and the
            // grouped bar chart degenerated into two thin stalks marooned
            // in a tall empty card. Saying so is better than drawing it.
            child: months.length < 2
                ? Center(
                    child: Text(
                      'Comes back once there are two months of history.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: _MonthlyComparisonChart(
                          months: months,
                          monthly: _monthly,
                          colorFor: _colorFor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _BankLegend(
                        bankCodes: _monthly.keys.toList(),
                        colorFor: _colorFor,
                        nameFor: _nameFor,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          const SectionHeader(title: 'Daily trend by bank'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 14),
            child: SizedBox(
              height: 210,
              child: MultiSeriesLineChart(
                series: [
                  for (final entry in _dailyPerBank.entries)
                    LineSeries(
                      label: _nameFor(entry.key),
                      color: _colorFor(entry.key),
                      points: entry.value,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankLegend extends StatelessWidget {
  final List<String> bankCodes;
  final Color Function(String) colorFor;
  final String Function(String) nameFor;

  const _BankLegend({
    required this.bankCodes,
    required this.colorFor,
    required this.nameFor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final code in bankCodes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colorFor(code),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              Text(nameFor(code), style: AppTextStyles.supporting),
            ],
          ),
      ],
    );
  }
}

class _MonthlyComparisonChart extends StatelessWidget {
  final List<DateTime> months;
  final Map<String, List<MonthlySpend>> monthly;
  final Color Function(String) colorFor;

  const _MonthlyComparisonChart({
    required this.months,
    required this.monthly,
    required this.colorFor,
  });

  double _totalFor(String bankCode, DateTime month) => monthly[bankCode]!
      .where((m) => m.month.year == month.year && m.month.month == month.month)
      .fold<double>(0, (sum, m) => sum + m.total);

  @override
  Widget build(BuildContext context) {
    final banks = monthly.keys.toList();

    var maxValue = 0.0;
    for (final month in months) {
      for (final bank in banks) {
        final v = _totalFor(bank, month);
        if (v > maxValue) maxValue = v;
      }
    }
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    // Widen the bars when there are few months so they read as columns
    // rather than hairlines; cap them so a long history stays legible.
    final barWidth = (80 / (months.length * banks.length)).clamp(8.0, 22.0);

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              Money.whole(rod.toY),
              AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 3,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value >= maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    Money.compact(value),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.supporting.copyWith(fontSize: 10.5),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM').format(months[i]),
                    style: AppTextStyles.supporting.copyWith(fontSize: 10.5),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                for (final bankCode in banks)
                  BarChartRodData(
                    toY: _totalFor(bankCode, months[i]),
                    color: colorFor(bankCode),
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
