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

  /// Human-readable interval, e.g. "Every 30 minutes", "Every 3 hours".
  static String describeInterval(int minutes) {
    if (minutes < 60) return 'Every $minutes minutes';
    final hours = minutes ~/ 60;
    return hours == 1 ? 'Every hour' : 'Every $hours hours';
  }
}
