import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// Placeholder for category/spend charts and week/month/year filters.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const ComingSoon(icon: Icons.space_dashboard_outlined),
    );
  }
}
