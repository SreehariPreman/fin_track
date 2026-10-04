import 'package:shared_preferences/shared_preferences.dart';

/// User-adjustable settings for the periodic background sync (see
/// background_sync_service.dart).
///
/// These live in SharedPreferences rather than in memory because the
/// background work runs in its own isolate, which shares no state with the
/// UI isolate — reading them from disk is the only way the worker can see
/// what was chosen in Settings.
class SyncPreferences {
  static const _enabledKey = 'sync_background_enabled';
  static const _notifyKey = 'sync_notifications_enabled';
  static const _intervalKey = 'sync_interval_minutes';
  static const _fetchCountKey = 'sync_fetch_count';
  static const _startDateKey = 'sync_tracking_start_date';
  static const _backfilledKey = 'sync_initial_backfill_done';

  /// Android's WorkManager refuses to run periodic work more often than
  /// every 15 minutes, so that's the floor regardless of what's chosen.
  static const intervalChoices = <int>[15, 30, 60, 180, 360];
  static const fetchCountChoices = <int>[10, 25, 50];

  static const defaultIntervalMinutes = 15;
  static const defaultFetchCount = 10;

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;

  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, value);

  Future<bool> notificationsEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_notifyKey) ?? true;

  Future<void> setNotificationsEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_notifyKey, value);

  Future<int> intervalMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_intervalKey) ?? defaultIntervalMinutes;

  Future<void> setIntervalMinutes(int value) async =>
      (await SharedPreferences.getInstance()).setInt(_intervalKey, value);

  /// How many recent mails each check looks at.
  Future<int> fetchCount() async =>
      (await SharedPreferences.getInstance()).getInt(_fetchCountKey) ?? defaultFetchCount;

  Future<void> setFetchCount(int value) async =>
      (await SharedPreferences.getInstance()).setInt(_fetchCountKey, value);

  /// The date tracking begins from. Mail older than this is never
  /// ingested, no matter which path does the fetching — so connecting an
  /// account with years of history in it doesn't drag all of it in.
  ///
  /// Null means no floor, which is how installs that predate this setting
  /// behave: they keep working exactly as before.
  Future<DateTime?> trackingStartDate() async {
    final millis = (await SharedPreferences.getInstance()).getInt(_startDateKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Stored date-only (midnight local), since the user picks a day, not a
  /// moment — and an IMAP SINCE search is day-granular anyway.
  ///
  /// Setting a date also clears [initialBackfillDone]: a new start date
  /// means a different stretch of history to collect, so the catch-up has
  /// to run again. Keeping that invariant here rather than at the call
  /// sites means changing the date can't silently skip the fetch.
  Future<void> setTrackingStartDate(DateTime value) async {
    final dayStart = DateTime(value.year, value.month, value.day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startDateKey, dayStart.millisecondsSinceEpoch);
    await prefs.setBool(_backfilledKey, false);
  }

  Future<void> clearTrackingStartDate() async =>
      (await SharedPreferences.getInstance()).remove(_startDateKey);

  /// Whether the one-off catch-up from [trackingStartDate] has run.
  ///
  /// Until it has, a fetch collects *everything* back to the start date
  /// and ignores [fetchCount] — that limit exists to keep routine checks
  /// cheap, and applying it to the initial catch-up would silently
  /// truncate the history the user just asked for. Afterwards the limit
  /// applies normally.
  Future<bool> initialBackfillDone() async =>
      (await SharedPreferences.getInstance()).getBool(_backfilledKey) ?? false;

  Future<void> setInitialBackfillDone(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_backfilledKey, value);

  /// Human-readable interval, e.g. "Every 30 minutes", "Every 3 hours".
  static String describeInterval(int minutes) {
    if (minutes < 60) return 'Every $minutes minutes';
    final hours = minutes ~/ 60;
    return hours == 1 ? 'Every hour' : 'Every $hours hours';
  }
}
