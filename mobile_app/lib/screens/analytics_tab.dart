import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// Placeholder for category/spend charts and week/month/year filters.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const ComingSoon(icon: Icons.bar_chart_outlined),
    );
  }
}
