import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// "‹ September 2026 ›" as a single pill. [canGoForward] should be false
/// once [month] is the current month, so you can't select a future one.
///
/// Reads as one control rather than three loose elements, which is what
/// the bare icon-text-icon row looked like floating on the canvas.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const MonthSelector({
    super.key,
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Arrow(icon: PhosphorIconsBold.caretLeft, onTap: onPrevious),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _Arrow(
              icon: PhosphorIconsBold.caretRight,
              onTap: canGoForward ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Arrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.backgroundAlt : Colors.transparent,
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
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 13,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// iOS-style segmented control used for the Analytics sub-tabs: a sunken
/// track with the selected segment lifted as a white pill. Clearer than an
/// underline indicator at four segments, and it reads as a control rather
/// than as page navigation — which is right, since it switches views
/// within one screen.
class SegmentedTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const SegmentedTabBar({super.key, required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        onTap: (_) => HapticFeedback.selectionClick(),
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x1416130F), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTextStyles.supporting.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        unselectedLabelStyle: AppTextStyles.supporting.copyWith(fontSize: 13),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [for (final t in tabs) Tab(height: 34, text: t)],
      ),
    );
  }
}
