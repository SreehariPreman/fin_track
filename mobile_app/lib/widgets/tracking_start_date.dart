import 'package:flutter/material.dart';

import '../services/sync_preferences.dart';
import '../theme/app_colors.dart';

/// Asks which date to start tracking from, and stores the answer.
///
/// Shared by the Gmail connect flow (where it's the natural follow-on
/// question) and Sync Settings (where it can be changed later), so the
/// bounds and wording can't drift between the two.
///
/// Returns the chosen date, or null if dismissed.
Future<DateTime?> pickTrackingStartDate(
  BuildContext context, {
  DateTime? current,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? today,
    // Two years is well past anything a mailbox search should be asked to
    // walk, and the future isn't a sensible answer — nothing has happened
    // there yet.
    firstDate: DateTime(today.year - 2, today.month, today.day),
    lastDate: today,
    helpText: 'Track transactions from',
    confirmText: 'Start here',
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
      ),
      child: child!,
    ),
  );
  if (picked == null) return null;

  await SyncPreferences().setTrackingStartDate(picked);
  return picked;
}
