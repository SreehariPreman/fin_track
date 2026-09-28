import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/analytics_filter.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/category_colors.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';
import '../widgets/coming_soon.dart';
import '../widgets/hero_balance_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/stat_tile.dart';

/// Home: a time-of-day greeting, the dark hero card carrying the month's
/// total, two supporting stats, an unlabelled-transactions nudge, and the
/// top spending categories (tapping one opens it in Analytics).
///
/// The old Income/Remaining tiles showed "₹—" because the parser doesn't
/// track credit vs debit yet. Two permanently blank tiles in the most
/// valuable slot on the screen cost more than they explained, so they're
/// replaced with figures we can actually compute; they come back when
/// direction parsing lands.
class HomeTab extends StatefulWidget {
  final VoidCallback onReviewUnlabelled;

  /// Called with (categoryId, categoryName) when a category row is
  /// tapped — null categoryId means the "Unlabelled" bucket, which has no
  /// analytics filter equivalent, so callers should just switch tabs.
  final void Function(int? categoryId, String categoryName) onCategoryTap;

  /// Whether this tab is the currently-selected one. Home is kept alive in
  /// RootScreen's IndexedStack (so the month selector etc. don't reset
  /// when you switch tabs), which means it otherwise wouldn't notice
  /// changes made elsewhere — e.g. saving your name in Settings, or
  /// fetching/labeling from Transactions — until reopening the app.
  /// Reload whenever this flips back to true.
  final bool active;

  const HomeTab({
    super.key,
    required this.onReviewUnlabelled,
    required this.onCategoryTap,
    required this.active,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _credentialsService = CredentialsService();
  final _analyticsService = AnalyticsService();
  final _db = DatabaseService.instance;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _loading = true;
  bool _hasError = false;
  String? _name;
  double _total = 0;
  double? _previousTotal;
  int _count = 0;
  int _unlabelledCount = 0;
  List<CategorySpend> _categories = [];
  List<DailySpend> _series = [];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  void _shiftMonth(int delta) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final range = DateRange.forMonth(_selectedMonth);
      final name = await _credentialsService.readDisplayName();
      final total = await _analyticsService.totalSpend(range, AnalyticsFilter.empty);
      final previousTotal = await _analyticsService.previousMonthTotal(_selectedMonth, AnalyticsFilter.empty);
      final count = await _analyticsService.transactionCount(range, AnalyticsFilter.empty);
      final unlabelledCount = await _db.getUnlabelledCount();
      final categories = await _analyticsService.categoryBreakdown(range, AnalyticsFilter.empty);
      final series = await _analyticsService.dailySeries(range, AnalyticsFilter.empty);
      if (!mounted) return;
      setState(() {
        _name = name;
        _total = total;
        _previousTotal = previousTotal;
        _count = count;
        _unlabelledCount = unlabelledCount;
        _categories = categories;
        _series = series;
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

  /// Greeting that tracks the clock — a small thing, but it's the first
  /// line on the screen and a static "Hi there" is what makes an app feel
  /// like a template.
  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: SafeArea(child: HomeSkeleton()));
    }
    if (_hasError) {
      return const Scaffold(
        body: SafeArea(
          child: ComingSoon(icon: PhosphorIconsRegular.warningCircle, message: 'Could not load your overview.'),
        ),
      );
    }

    final days = DateRange.forMonth(_selectedMonth).span.inDays.clamp(1, 1000);
    final greetingName = (_name != null && _name!.isNotEmpty) ? _name! : 'there';

    // Sections fade/rise in sequence rather than all at once. The stagger
    // is small (60ms) — enough to read as "assembling", not as a delay.
    var step = 0;
    Widget stagger(Widget child) {
      final delay = (60 * step++).ms;
      return child
          .animate()
          .fadeIn(delay: delay, duration: 320.ms, curve: Curves.easeOut)
          .slideY(begin: 0.08, end: 0, delay: delay, duration: 380.ms, curve: Curves.easeOutCubic);
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter, 8, AppTheme.gutter, AppTheme.sectionGap),
            children: [
              stagger(_Greeting(greeting: _timeGreeting, name: greetingName)),
              const SizedBox(height: AppTheme.sectionGap),
              stagger(HeroBalanceCard(
                month: _selectedMonth,
                total: _total,
                previousTotal: _previousTotal,
                series: [for (final d in _series) d.total],
                canGoForward: !_isCurrentMonth,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              )),
              const SizedBox(height: AppTheme.gap),
              stagger(Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: PhosphorIconsRegular.receipt,
                      value: '$_count',
                      label: _count == 1 ? 'Transaction' : 'Transactions',
                    ),
                  ),
                  const SizedBox(width: AppTheme.gap),
                  Expanded(
                    child: StatTile(
                      icon: PhosphorIconsRegular.chartBar,
                      value: Money.whole(_total / days),
                      label: 'Avg. per day',
                    ),
                  ),
                ],
              )),
              if (_unlabelledCount > 0) ...[
                const SizedBox(height: AppTheme.gap),
                stagger(_UnlabelledNudge(
                  count: _unlabelledCount,
                  onTap: widget.onReviewUnlabelled,
                )),
              ],
              const SizedBox(height: AppTheme.sectionGap),
              stagger(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Spending',
                    actionLabel: _categories.isEmpty ? null : 'Breakdown',
                    onAction: _categories.isEmpty
                        ? null
                        : () => widget.onCategoryTap(null, 'All'),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: _categories.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No categorised spending this month.',
                                style: AppTextStyles.bodySecondary,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (final c in _categories.take(5))
                                _CategoryRow(
                                  category: c,
                                  total: _total,
                                  onTap: () => widget.onCategoryTap(c.categoryId, c.categoryName),
                                ),
                            ],
                          ),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String greeting;
  final String name;

  const _Greeting({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    // No avatar alongside this: it wasn't interactive, and the profile it
    // implied already lives behind the Settings tab. Dropping it also
    // gives a long name the full width.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTextStyles.overline),
        const SizedBox(height: 6),
        Text(
          name,
          style: AppTextStyles.screenTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _UnlabelledNudge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _UnlabelledNudge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TintedPanel(
      color: AppColors.warningSoft,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(PhosphorIconsFill.tag, size: 18, color: AppColors.warning),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count transaction${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} a label',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text('Tap to review', style: AppTextStyles.supporting),
              ],
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight, size: 13, color: AppColors.warning),
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            category.categoryId != null
                ? CategoryAvatar(categoryId: category.categoryId!, name: category.categoryName, size: 38)
                : const NeedsLabelAvatar(size: 38),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }
}
