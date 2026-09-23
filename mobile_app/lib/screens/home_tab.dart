import 'package:flutter/material.dart';

/// Placeholder landing tab. Dashboards/summaries land here in a later phase.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fin Track')),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}
