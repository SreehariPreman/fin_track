import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_text_styles.dart';

/// "‹ September 2026 ›" — used by Home and Analytics to page through
/// months. [canGoForward] should be false once [month] is the current
/// month, so you can't select a future month.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const MonthSelector({
    super.key,
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Text(DateFormat('MMMM yyyy').format(month), style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
          IconButton(
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
