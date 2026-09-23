import 'package:flutter/material.dart';

/// Placeholder for category/spend charts and week/month/year filters.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}
