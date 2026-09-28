import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/transaction.dart';
import '../screens/label_transaction_screen.dart';
import '../screens/transaction_detail_screen.dart';
import 'database_service.dart';

/// Shows the "New transaction" notification and routes a tap on it (or on
/// its "Label Now" action) straight to the right screen — never just to
/// the Transactions list.
///
/// Two ways a tap reaches the app, both handled:
/// - **Warm**: the app's Dart isolate is already running (foreground or
///   backgrounded) — [_onResponse] fires immediately.
/// - **Cold**: the app process was killed; tapping the notification
///   launches a fresh process. [init] checks
///   [FlutterLocalNotificationsPlugin.getNotificationAppLaunchDetails] for
///   this and stores the request until [navigatorKey] has a live
///   [NavigatorState] to push onto (RootScreen calls [consumePending]
///   after its first frame).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'new_transactions';
  static const _channelName = 'New transactions';
  static const _channelDescription = 'Alerts when a new UPI transaction is fetched from your inbox.';
  static const labelActionId = 'label_now';

  final plugin = FlutterLocalNotificationsPlugin();
  final navigatorKey = GlobalKey<NavigatorState>();

  Map<String, Object?>? _pending;

  /// Creates the Android notification channel. Safe to call from the
  /// background sync isolate (a separate instance of this class, since
  /// isolates don't share static state) — it doesn't touch navigation.
  Future<void> ensureChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Full app-side setup: channel + tap handling + cold-start detection.
  /// Call once, early in main().
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );
    await ensureChannel();

    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      _storePending(response);
    }
  }

  /// Android 13+ requires this at runtime; a no-op on older versions.
  /// Best asked right after the user sets up their Gmail connection, since
  /// that's the point background sync — and therefore notifications —
  /// starts actually doing something.
  Future<void> requestPermission() async {
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _onResponse(NotificationResponse response) {
    _storePending(response);
    consumePending();
  }

  void _storePending(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final txnId = data['txnId'] as int?;
      if (txnId == null) return;
      _pending = {'txnId': txnId, 'label': response.actionId == labelActionId};
    } catch (_) {
      // Malformed/foreign payload — ignore rather than crash on tap.
    }
  }

  /// Acts on a stored notification tap once the navigator is ready. Safe
  /// to call speculatively (e.g. from RootScreen's first frame) — it's a
  /// no-op when there's nothing pending or the navigator isn't mounted yet.
  void consumePending() {
    final pending = _pending;
    final nav = navigatorKey.currentState;
    if (pending == null || nav == null) return;
    _pending = null;
    _openTransaction(nav, pending['txnId'] as int, pending['label'] as bool);
  }

  Future<void> _openTransaction(NavigatorState nav, int txnId, bool wantsLabel) async {
    final txn = await DatabaseService.instance.getTransactionById(txnId);
    if (txn == null) return; // deleted since the notification fired
    if (wantsLabel) {
      nav.push(MaterialPageRoute(builder: (_) => LabelTransactionScreen(transaction: txn)));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: txn)));
    }
  }

  /// Shows the "New transaction" notification for [t], with a "Label Now"
  /// action that opens the label screen directly — never the Transactions
  /// list. [t.id] must be set (i.e. already saved).
  Future<void> showNewTransaction(UpiTransaction t) async {
    final id = t.id;
    if (id == null) return;

    final amountStr = t.amount != null ? '₹${t.amount!.toStringAsFixed(0)}' : 'Amount unknown';
    final subtitleParts = [t.displayName, if (t.bankName != null) t.bankName!];
    final body = '$amountStr\n${subtitleParts.join(' · ')}\n\nNeeds labeling';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(labelActionId, 'Label Now', showsUserInterface: true),
      ],
    );

    await plugin.show(
      id: id,
      title: 'New transaction',
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode({'txnId': id}),
    );
  }
}
