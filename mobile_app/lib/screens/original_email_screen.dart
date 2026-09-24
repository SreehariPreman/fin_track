import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';

/// Shows the raw parsed email body. Kept out of the main transaction detail
/// screen so that screen stays scannable — this is opt-in via "View
/// Original Email".
///
/// Note: this currently shows the plain-text body (HTML tags already
/// stripped when the mail was fetched). True original-formatting HTML
/// rendering is tracked as a separate backlog item — it needs the raw
/// HTML captured at fetch time plus an HTML-rendering widget, both out of
/// scope for this pass.
class OriginalEmailScreen extends StatelessWidget {
  final String subject;
  final String body;

  const OriginalEmailScreen({super.key, required this.subject, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Original email')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              Text(body.isEmpty ? '(empty)' : body, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }
}
