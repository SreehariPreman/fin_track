import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../services/bank_profiles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/coming_soon.dart';

class BanksTab extends StatefulWidget {
  final DateRange range;
  final AnalyticsFilter filter;
  final DateTime selectedMonth;

  const BanksTab({super.key, required this.range, required this.filter, required this.selectedMonth});

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return const ComingSoon(icon: Icons.error_outline, message: 'Could not load analytics.');
    }
    if (_banks.isEmpty) {
      return const ComingSoon(icon: Icons.account_balance_outlined, message: 'No transactions in this period.');
    }

    final total = _banks.fold<double>(0, (sum, b) => sum + b.total);

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
                Text('Spending by Bank', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 52,
                          sections: [
                            for (final b in _banks)
                              PieChartSectionData(
                                value: b.total,
                                color: bankProfileForCode(b.bankCode)?.badgeColor ?? AppColors.textMuted,
                                radius: 28,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${total.toStringAsFixed(0)}', style: AppTextStyles.amountLarge.copyWith(fontSize: 20)),
                          Text('Total Spent', style: AppTextStyles.supporting),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final b in _banks) _LegendRow(bank: b),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly Comparison', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 16),
                SizedBox(height: 160, child: _MonthlyComparisonChart(monthly: _monthly)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank Wise Trend', style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 16),
                SizedBox(height: 160, child: _BankTrendChart(dailyPerBank: _dailyPerBank)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final BankSpend bank;

  const _LegendRow({required this.bank});

  @override
  Widget build(BuildContext context) {
    final color = bankProfileForCode(bank.bankCode)?.badgeColor ?? AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(bank.bankName, style: AppTextStyles.body)),
          Text('₹${bank.total.toStringAsFixed(0)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MonthlyComparisonChart extends StatelessWidget {
  final Map<String, List<MonthlySpend>> monthly;

  const _MonthlyComparisonChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }

    // Union of all months present, in order.
    final months = <DateTime>{};
    for (final series in monthly.values) {
      for (final m in series) {
        months.add(DateTime(m.month.year, m.month.month));
      }
    }
    final sortedMonths = months.toList()..sort();
    final banks = monthly.keys.toList();

    double maxY = 0;
    for (final series in monthly.values) {
      for (final m in series) {
        if (m.total > maxY) maxY = m.total;
      }
    }

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= sortedMonths.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('MMM').format(sortedMonths[i]), style: AppTextStyles.supporting),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < sortedMonths.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                for (final bankCode in banks)
                  BarChartRodData(
                    toY: monthly[bankCode]!
                        .where((m) => m.month.year == sortedMonths[i].year && m.month.month == sortedMonths[i].month)
                        .fold<double>(0, (sum, m) => sum + m.total),
                    color: bankProfileForCode(bankCode)?.badgeColor ?? AppColors.textMuted,
                    width: 10,
                    borderRadius: BorderRadius.circular(3),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BankTrendChart extends StatelessWidget {
  final Map<String, List<DailySpend>> dailyPerBank;

  const _BankTrendChart({required this.dailyPerBank});

  @override
  Widget build(BuildContext context) {
    final hasEnough = dailyPerBank.values.any((s) => s.length >= 2);
    if (!hasEnough) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }

    double maxY = 0;
    for (final series in dailyPerBank.values) {
      for (final d in series) {
        if (d.total > maxY) maxY = d.total;
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          for (final entry in dailyPerBank.entries)
            LineChartBarData(
              spots: [for (var i = 0; i < entry.value.length; i++) FlSpot(i.toDouble(), entry.value[i].total)],
              isCurved: true,
              color: bankProfileForCode(entry.key)?.badgeColor ?? AppColors.textMuted,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
