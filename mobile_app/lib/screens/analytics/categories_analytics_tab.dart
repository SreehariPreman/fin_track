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
import '../../widgets/category_avatar.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/skeleton.dart';
import 'category_transactions_screen.dart';

/// "Category Spending" — categories sorted by spend, each with count,
/// amount, percentage, and a progress bar. Deliberately a readable list,
/// not a big pie chart (that's on Overview).
class CategoriesAnalyticsTab extends StatefulWidget {
  final DateRange range;
  final AnalyticsFilter filter;

  const CategoriesAnalyticsTab({super.key, required this.range, required this.filter});

  @override
  State<CategoriesAnalyticsTab> createState() => _CategoriesAnalyticsTabState();
}

class _CategoriesAnalyticsTabState extends State<CategoriesAnalyticsTab> {
  final _service = AnalyticsService();
  bool _loading = true;
  bool _hasError = false;
  List<CategorySpend> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CategoriesAnalyticsTab old) {
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
      final categories = await _service.categoryBreakdown(widget.range, widget.filter);
      if (!mounted) return;
      setState(() {
        _categories = categories;
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
    if (_loading) return const AnalyticsSkeleton();
    if (_hasError) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.warningCircle,
        message: 'Could not load analytics.',
      );
    }
    if (_categories.isEmpty) {
      return const ComingSoon(
        icon: PhosphorIconsRegular.chartPieSlice,
        message: 'No transactions in this period.',
      );
    }

    final total = _categories.fold<double>(0, (sum, c) => sum + c.total);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _categories.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 70, endIndent: 16),
                  _CategoryRow(
                    category: _categories[i],
                    total: total,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryTransactionsScreen(
                          categoryId: _categories[i].categoryId,
                          categoryName: _categories[i].categoryName,
                          range: widget.range,
                          filter: widget.filter,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategorySpend category;
  final double total;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (category.total / total).clamp(0, 1).toDouble() : 0.0;
    final color = category.categoryId != null
        ? CategoryColors.forId(category.categoryId!)
        : AppColors.warning;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            category.categoryId != null
                ? CategoryAvatar(
                    categoryId: category.categoryId!,
                    name: category.categoryName,
                    size: 40,
                  )
                : const NeedsLabelAvatar(size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.categoryName,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(Money.whole(category.total), style: AppTextStyles.amount),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${category.count} transaction${category.count == 1 ? '' : 's'}',
                    style: AppTextStyles.supporting,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: AppColors.backgroundAlt,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        // Wide enough for "100%" — at 32 it wrapped onto
                        // a second line once a category hit the full bar.
                        width: 40,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          softWrap: false,
                          style: AppTextStyles.supporting,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(PhosphorIconsBold.caretRight, size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
