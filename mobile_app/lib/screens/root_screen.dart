import 'package:flutter/material.dart';

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

  static const _tabs = [
    HomeTab(),
    TransactionsScreen(),
    AnalyticsTab(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
