import 'package:flutter/material.dart';

import '../../models/analytics_filter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/category_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/coming_soon.dart';

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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return const ComingSoon(icon: Icons.error_outline, message: 'Could not load analytics.');
    }
    if (_categories.isEmpty) {
      return const ComingSoon(icon: Icons.pie_chart_outline, message: 'No transactions in this period.');
    }

    final total = _categories.fold<double>(0, (sum, c) => sum + c.total);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final c in _categories) _CategoryRow(category: c, total: total),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategorySpend category;
  final double total;

  const _CategoryRow({required this.category, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (category.total / total).clamp(0, 1).toDouble() : 0.0;
    final color = category.categoryId != null ? CategoryColors.forId(category.categoryId!) : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            category.categoryId != null
                ? CategoryAvatar(categoryId: category.categoryId!, name: category.categoryName, size: 40)
                : const NeedsLabelAvatar(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(category.categoryName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('₹${category.total.toStringAsFixed(0)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${category.count} transaction${category.count == 1 ? '' : 's'}', style: AppTextStyles.supporting),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(pct * 100).toStringAsFixed(0)}%', style: AppTextStyles.supporting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
