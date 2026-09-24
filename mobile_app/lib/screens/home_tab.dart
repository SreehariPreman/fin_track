import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// Placeholder landing tab. Dashboards/summaries land here in a later phase.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpendTrack')),
      body: const ComingSoon(icon: Icons.home_outlined),
    );
  }
}
