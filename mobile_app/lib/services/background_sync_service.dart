import 'package:workmanager/workmanager.dart';

import 'credentials_service.dart';
import 'database_service.dart';
import 'imap_service.dart';
import 'notification_service.dart';
import 'sync_preferences.dart';

/// Periodic background sync (Android `WorkManager`, via the `workmanager`
/// plugin): the only way to check mail without the app open. This is
/// explicitly a periodic *poll*, not a push — Android does not let a
/// Flutter app run continuously in the background or react to Gmail in
/// real time, and WorkManager itself won't run periodic work more often
/// than every 15 minutes regardless of what's requested. So: "new mail up
/// to ~15–30 minutes late, with a notification" rather than "instant".
///
/// Flow: periodic WorkManager task -> IMAP fetch (same path Transactions'
/// manual Fetch uses) -> diff against what's already stored -> save ->
/// notify only for genuinely new ones.
class BackgroundSyncService {
  static const _uniqueTaskName = 'fin_track_periodic_sync';
  static const _taskName = 'syncTransactions';

  /// Registers the callback dispatcher with the OS. Cheap and idempotent
  /// — call unconditionally at app startup, before any registration.
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Schedules (or leaves alone, if already scheduled) the periodic sync
  /// at whatever interval Sync Settings holds. Call after Gmail
  /// credentials are saved, and again at startup if credentials already
  /// exist. Does nothing if background sync has been switched off.
  static Future<void> register() async {
    final prefs = SyncPreferences();
    if (!await prefs.isEnabled()) {
      await cancel();
      return;
    }
    await _schedule(await prefs.intervalMinutes(), ExistingPeriodicWorkPolicy.keep);
  }

  /// Re-schedules at [intervalMinutes], replacing any existing schedule —
  /// used when the interval is changed in Sync Settings, where `keep`
  /// would silently leave the old period in place.
  static Future<void> reschedule(int intervalMinutes) =>
      _schedule(intervalMinutes, ExistingPeriodicWorkPolicy.update);

  static Future<void> _schedule(int intervalMinutes, ExistingPeriodicWorkPolicy policy) async {
    await Workmanager().registerPeriodicTask(
      _uniqueTaskName,
      _taskName,
      frequency: Duration(minutes: intervalMinutes),
      existingWorkPolicy: policy,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancel() => Workmanager().cancelByUniqueName(_uniqueTaskName);
}

/// Entry point for the background isolate WorkManager spawns. Must stay
/// top-level (or static) and keep this exact `@pragma` so the Android side
/// can find it by name after an app restart/reboot.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _syncAndNotify();
    } catch (_) {
      // Swallow: a failed sync (no network, bad credentials, IMAP hiccup)
      // shouldn't crash the worker — WorkManager will just try again next
      // period. There's no UI here to show an error to.
    }
    return true;
  });
}

Future<void> _syncAndNotify() async {
  final syncPrefs = SyncPreferences();
  if (!await syncPrefs.isEnabled()) return;

  final credentialsService = CredentialsService();
  final email = await credentialsService.readEmail();
  final passcode = await credentialsService.readAppPasscode();
  if (email == null || email.isEmpty || passcode == null || passcode.isEmpty) {
    return; // not set up yet
  }

  // Until the one-off catch-up from the tracking start date has run,
  // collect everything back to that date; the per-check limit exists to
  // keep routine polls cheap and would silently truncate the history the
  // user asked to start from.
  final startDate = await syncPrefs.trackingStartDate();
  final backfilled = await syncPrefs.initialBackfillDone();
  final isBackfill = startDate != null && !backfilled;

  final fetched = await ImapService().fetchLastUpiTransactions(
    email: email,
    appPasscode: passcode,
    maxCount: isBackfill ? null : await syncPrefs.fetchCount(),
    since: startDate,
  );
  if (isBackfill) await syncPrefs.setInitialBackfillDone(true);
  if (fetched.isEmpty) return;

  final db = DatabaseService.instance;
  final existingIds = await db.getExistingEmailIds(fetched.map((t) => t.emailId).toList());
  final newOnes = fetched.where((t) => !existingIds.contains(t.emailId)).toList();

  // Upserts everything (refreshes previously-seen rows too, same as a
  // manual Fetch) — but only the ones absent beforehand are "new".
  await db.insertNewTransactions(fetched);
  if (newOnes.isEmpty) return;
  if (!await syncPrefs.notificationsEnabled()) return;

  final notificationService = NotificationService.instance;
  await notificationService.ensureChannel();

  // Re-read to pick up the local row ids the insert just assigned.
  final saved = await db.getAllTransactions();
  final byEmailId = {for (final t in saved) t.emailId: t};

  var notified = 0;
  const maxNotificationsPerSync = 5; // avoid a notification storm in one go
  for (final t in newOnes) {
    if (notified >= maxNotificationsPerSync) break;
    final withId = byEmailId[t.emailId];
    if (withId == null) continue;
    await notificationService.showNewTransaction(withId);
    notified++;
  }
}
