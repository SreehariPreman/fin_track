import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money.dart';

/// The one surface in the app that isn't a white card.
///
/// Everything else is white-on-paper, so putting the headline number on a
/// saturated jade ground is what gives the screen a focal point — without
/// it the eye has nowhere to land and the layout reads as an
/// undifferentiated stack of cards. Deliberately not reused elsewhere: a
/// second full-bleed colour surface would cancel the effect.
class HeroBalanceCard extends StatelessWidget {
  final DateTime month;
  final double total;
  final double? previousTotal;

  /// Daily totals for the sparkline; fewer than 2 points hides it.
  final List<double> series;

  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const HeroBalanceCard({
    super.key,
    required this.month,
    required this.total,
    required this.previousTotal,
    required this.series,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    double? changePct;
    if (previousTotal != null && previousTotal! > 0) {
      changePct = ((total - previousTotal!) / previousTotal!) * 100;
    }
    final previousMonthName =
        DateFormat('MMMM').format(DateTime(month.year, month.month - 1));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.heroShadow,
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthNav(
            month: month,
            canGoForward: canGoForward,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
          const SizedBox(height: 20),
          Text(
            'TOTAL SPENT',
            style: AppTextStyles.overline.copyWith(color: AppColors.onInkMuted),
          ),
          const SizedBox(height: 8),
          Text(
            Money.whole(total),
            style: AppTextStyles.display.copyWith(color: AppColors.onInk),
          ),
          if (changePct != null) ...[
            const SizedBox(height: 14),
            _DeltaPill(changePct: changePct, previousMonthName: previousMonthName),
          ],
          if (series.length >= 2) ...[
            const SizedBox(height: 18),
            SizedBox(height: 58, child: _Sparkline(series: series)),
          ],
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthNav({
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            style: AppTextStyles.body.copyWith(
              color: AppColors.onInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _NavButton(icon: PhosphorIconsBold.caretLeft, onTap: onPrevious),
        const SizedBox(width: 8),
        _NavButton(
          icon: PhosphorIconsBold.caretRight,
          onTap: canGoForward ? onNext : null,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.10 : 0.04),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 15,
            color: enabled ? AppColors.onInk : AppColors.onInkMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double changePct;
  final String previousMonthName;

  const _DeltaPill({required this.changePct, required this.previousMonthName});

  @override
  Widget build(BuildContext context) {
    final up = changePct >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? PhosphorIconsBold.arrowUpRight : PhosphorIconsBold.arrowDownRight,
            size: 13,
            // Spending more is the bad direction, so up is warm and down
            // is cool — inverted relative to a stock-price chart.
            color: up ? const Color(0xFFFFCE8F) : const Color(0xFFA8EFCE),
          ),
          const SizedBox(width: 5),
          Text(
            '${changePct.abs().toStringAsFixed(0)}% vs $previousMonthName',
            style: AppTextStyles.supporting.copyWith(
              color: AppColors.onInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> series;

  const _Sparkline({required this.series});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i]),
    ];
    final maxY = series.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            color: Colors.white,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            // The fill is what turns a bare stroke into something that
            // reads as a chart rather than a scribble.
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
