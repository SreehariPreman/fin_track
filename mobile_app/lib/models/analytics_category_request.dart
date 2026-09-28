/// Carries a "jump to Analytics, Categories tab, filtered by this
/// category" request from Home to AnalyticsTab (via a ValueNotifier
/// RootScreen owns) — the same cross-tab pattern used for Home's
/// "Tap to review" -> Transactions' Unlabelled filter.
class AnalyticsCategoryRequest {
  final int categoryId;
  final String categoryName;

  const AnalyticsCategoryRequest({required this.categoryId, required this.categoryName});
}
