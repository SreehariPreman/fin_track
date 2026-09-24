import 'package:flutter/material.dart';

import 'dashboard_tab.dart';
import 'home_tab.dart';
import 'profile_screen.dart';
import 'sync_screen.dart';

/// Bottom-nav shell: Home / Dashboard / Sync / Profile.
/// Each tab keeps its own state via IndexedStack (e.g. Sync's fetched list
/// and Profile's form stay intact when you switch tabs and come back).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const _tabs = [
    HomeTab(),
    DashboardTab(),
    SyncScreen(),
    ProfileScreen(),
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
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.sync_outlined), label: 'Sync'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
