import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money.dart';

/// Shared chart pieces.
///
/// The old charts had `gridData`, `titlesData` and `lineTouchData` all
/// switched off, which made them decorative — you could see a shape but
/// not read a value off it. These put the axes and the tooltip back.
class SpendLineChart extends StatelessWidget {
  final List<DailySpend> series;

  const SpendLineChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }

    final spots = [
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].total),
    ];
    final maxValue = series.map((s) => s.total).reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    // Aim for ~5 date labels regardless of range length, so a 31-day
    // month doesn't render an unreadable smear along the axis.
    final labelEvery = (series.length / 5).ceil().clamp(1, series.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                if (i % labelEvery != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d MMM').format(series[i].date),
                    style: AppTextStyles.supporting.copyWith(fontSize: 10.5),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(series[spot.x.toInt()].date)}\n',
                  AppTextStyles.supporting.copyWith(color: AppColors.onInkMuted),
                  children: [
                    TextSpan(
                      text: Money.whole(spot.y),
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          getTouchedSpotIndicator: (barData, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                const FlLine(color: AppColors.primary, strokeWidth: 1.5),
                FlDotData(
                  getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                    radius: 4.5,
                    color: AppColors.card,
                    strokeWidth: 2.5,
                    strokeColor: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            color: AppColors.primary,
            barWidth: 2.6,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One slice of a [DonutChart].
class DonutSlice {
  final String label;
  final double value;
  final Color color;

  const DonutSlice({required this.label, required this.value, required this.color});
}

/// Donut with the total in the hole. A ring on its own only shows
/// proportion; putting the figure at the centre means the chart answers
/// "how much" and "split how" at the same glance.
///
/// Generic over what the slices represent, so the categories donut and the
/// banks donut are the same ring at the same weight rather than two
/// hand-tuned charts that drifted apart.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double total;

  const DonutChart({super.key, required this.slices, required this.total});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 62,
            startDegreeOffset: -90,
            sections: [
              for (final s in slices)
                PieChartSectionData(
                  value: s.value,
                  color: s.color,
                  radius: 20,
                  showTitle: false,
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TOTAL', style: AppTextStyles.overline.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              Money.whole(total),
              style: AppTextStyles.amountLarge.copyWith(fontSize: 21),
            ),
          ],
        ),
      ],
    );
  }
}

/// Legend row beneath a donut: colour swatch, name, amount, share.
class ChartLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double value;
  final double total;

  const ChartLegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(Money.whole(value), style: AppTextStyles.amount),
          SizedBox(
            width: 44,
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: AppTextStyles.supporting,
            ),
          ),
        ],
      ),
    );
  }
}

/// One named series in a [MultiSeriesLineChart].
class LineSeries {
  final String label;
  final Color color;
  final List<DailySpend> points;

  const LineSeries({required this.label, required this.color, required this.points});
}

/// Several lines on shared axes, with a legend.
///
/// Without the legend a multi-line chart is unreadable by construction —
/// you can see three coloured lines but nothing says which is which.
class MultiSeriesLineChart extends StatelessWidget {
  final List<LineSeries> series;

  const MultiSeriesLineChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final drawable = series.where((s) => s.points.length >= 2).toList();
    if (drawable.isEmpty) {
      return Center(child: Text('Not enough data yet', style: AppTextStyles.supporting));
    }

    var maxValue = 0.0;
    var longest = 0;
    for (final s in drawable) {
      for (final p in s.points) {
        if (p.total > maxValue) maxValue = p.total;
      }
      if (s.points.length > longest) longest = s.points.length;
    }
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final reference = drawable.reduce((a, b) => a.points.length >= b.points.length ? a : b).points;
    final labelEvery = (longest / 4).ceil().clamp(1, longest);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
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
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= reference.length) return const SizedBox.shrink();
                      if (i % labelEvery != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('d MMM').format(reference[i].date),
                          style: AppTextStyles.supporting.copyWith(fontSize: 10.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                for (final s in drawable)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.points.length; i++)
                        FlSpot(i.toDouble(), s.points[i].total),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: s.color,
                    barWidth: 2.4,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in drawable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(s.label, style: AppTextStyles.supporting),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
