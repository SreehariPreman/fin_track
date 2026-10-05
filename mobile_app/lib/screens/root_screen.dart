import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/analytics_category_request.dart';
import '../services/notification_service.dart';
import 'analytics_tab.dart';
import 'home_tab.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

/// Bottom-nav shell: Home / Transactions / Analytics / Settings.
/// Each tab keeps its own state via IndexedStack (e.g. Transactions' fetched
/// list and Settings' form stay intact when you switch tabs and come back).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  /// Home's "Tap to review" sets this to 'unlabelled' and switches to the
  /// Transactions tab; Transactions picks it up and clears it back to null.
  final _pendingTransactionsFilter = ValueNotifier<String?>(null);

  /// Home's category rows set this and switch to the Analytics tab;
  /// AnalyticsTab picks it up, jumps to Categories, and applies the filter.
  final _pendingAnalyticsCategory = ValueNotifier<AnalyticsCategoryRequest?>(null);

  @override
  void initState() {
    super.initState();
    // Handles the cold-start case: the app was launched by tapping a
    // notification, so NotificationService already has a pending
    // navigation request from before this widget (and its navigatorKey)
    // existed. A warm tap (app already running) is handled directly by
    // NotificationService's own response callback instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.consumePending();
    });
  }

  @override
  void dispose() {
    _pendingTransactionsFilter.dispose();
    _pendingAnalyticsCategory.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  void _reviewUnlabelled() {
    _pendingTransactionsFilter.value = 'unlabelled';
    _goToTab(1);
  }

  void _viewCategoryInAnalytics(int? categoryId, String categoryName) {
    // Unlabelled (null categoryId) has no Analytics filter equivalent —
    // just switch tabs so they land on the Categories breakdown, which
    // still shows an Unlabelled row.
    if (categoryId != null) {
      _pendingAnalyticsCategory.value =
          AnalyticsCategoryRequest(categoryId: categoryId, categoryName: categoryName);
    }
    _goToTab(2);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(
        onReviewUnlabelled: _reviewUnlabelled,
        onCategoryTap: _viewCategoryInAnalytics,
        active: _index == 0,
      ),
      TransactionsScreen(
        pendingFilter: _pendingTransactionsFilter,
        active: _index == 1,
      ),
      AnalyticsTab(pendingCategoryRequest: _pendingAnalyticsCategory),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        // Selection is carried by the outline -> fill icon swap (the
        // theme clears NavigationBar's pill indicator), which is why each
        // destination needs both weights.
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.houseSimple),
            selectedIcon: Icon(PhosphorIconsFill.houseSimple),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.receipt),
            selectedIcon: Icon(PhosphorIconsFill.receipt),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.chartPieSlice),
            selectedIcon: Icon(PhosphorIconsFill.chartPieSlice),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.gearSix),
            selectedIcon: Icon(PhosphorIconsFill.gearSix),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
