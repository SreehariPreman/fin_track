import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/background_sync_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/settings_group.dart';
import '../../widgets/tracking_start_date.dart';

/// How often the app checks Gmail in the background, and what it does when
/// it finds something.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _prefs = SyncPreferences();

  bool _loading = true;
  bool _enabled = true;
  bool _notify = true;
  int _intervalMinutes = SyncPreferences.defaultIntervalMinutes;
  int _fetchCount = SyncPreferences.defaultFetchCount;
  DateTime? _startDate;
  bool _backfillDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _prefs.isEnabled();
    final notify = await _prefs.notificationsEnabled();
    final interval = await _prefs.intervalMinutes();
    final fetchCount = await _prefs.fetchCount();
    final startDate = await _prefs.trackingStartDate();
    final backfillDone = await _prefs.initialBackfillDone();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _notify = notify;
      _intervalMinutes = interval;
      _fetchCount = fetchCount;
      _startDate = startDate;
      _backfillDone = backfillDone;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await _prefs.setEnabled(value);
    if (value) {
      await BackgroundSyncService.reschedule(_intervalMinutes);
    } else {
      await BackgroundSyncService.cancel();
    }
  }

  Future<void> _setNotify(bool value) async {
    setState(() => _notify = value);
    await _prefs.setNotificationsEnabled(value);
    if (value) {
      try {
        await NotificationService.instance.requestPermission();
      } catch (_) {
        // Permission dialogs are best-effort; the toggle still holds.
      }
    }
  }

  Future<void> _pickInterval() async {
    final choice = await _pick<int>(
      title: 'Check for new mail',
      options: SyncPreferences.intervalChoices,
      selected: _intervalMinutes,
      label: SyncPreferences.describeInterval,
    );
    if (choice == null) return;
    setState(() => _intervalMinutes = choice);
    await _prefs.setIntervalMinutes(choice);
    if (_enabled) await BackgroundSyncService.reschedule(choice);
  }

  Future<void> _pickTrackingStartDate() async {
    final picked = await pickTrackingStartDate(context, current: _startDate);
    if (picked == null || !mounted) return;
    // Changing the date clears the backfill flag (see SyncPreferences), so
    // reflect that here rather than showing a stale "caught up".
    setState(() {
      _startDate = picked;
      _backfillDone = false;
    });
  }

  Future<void> _pickFetchCount() async {
    final choice = await _pick<int>(
      title: 'Emails per check',
      options: SyncPreferences.fetchCountChoices,
      selected: _fetchCount,
      label: (value) => '$value most recent',
    );
    if (choice == null) return;
    setState(() => _fetchCount = choice);
    await _prefs.setFetchCount(choice);
  }

  Future<T?> _pick<T>({
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) label,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final option in options)
            ListTile(
              title: Text(label(option), style: AppTextStyles.body),
              trailing: option == selected
                  ? Icon(PhosphorIconsBold.check, size: 20, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SettingsGroup(
                  title: 'Background sync',
                  children: [
                    _SwitchRow(
                      icon: PhosphorIconsRegular.arrowsClockwise,
                      label: 'Check Gmail automatically',
                      supporting: _enabled ? 'On' : 'Off',
                      value: _enabled,
                      onChanged: _setEnabled,
                    ),
                    SettingsRow(
                      icon: PhosphorIconsRegular.clock,
                      label: 'Frequency',
                      supporting: SyncPreferences.describeInterval(_intervalMinutes),
                      onTap: _enabled ? _pickInterval : null,
                    ),
                    SettingsRow(
                      icon: PhosphorIconsRegular.envelopeSimple,
                      label: 'Emails per check',
                      supporting: '$_fetchCount most recent',
                      onTap: _enabled ? _pickFetchCount : null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: 'History',
                  children: [
                    SettingsRow(
                      icon: PhosphorIconsRegular.calendarBlank,
                      label: 'Track from',
                      supporting: _startDate == null
                          ? 'Not set — recent mail only'
                          : DateFormat('d MMM yyyy').format(_startDate!),
                      accent: _startDate == null ? AppColors.warning : null,
                      onTap: _pickTrackingStartDate,
                    ),
                    if (_startDate != null)
                      SettingsRow(
                        icon: _backfillDone
                            ? PhosphorIconsRegular.checkCircle
                            : PhosphorIconsRegular.clockCountdown,
                        label: 'Catching up',
                        supporting: _backfillDone
                            ? 'Done — only new mail from now on'
                            : 'Next check collects everything since this date',
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: 'Notifications',
                  children: [
                    _SwitchRow(
                      icon: PhosphorIconsRegular.bell,
                      label: 'Notify on new transactions',
                      supporting: _notify ? 'On' : 'Off',
                      value: _notify,
                      onChanged: _setNotify,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Android will not run background work more than once every '
                    '15 minutes, and may delay a check further while the phone '
                    'is idle. Pull to refresh on Transactions for an immediate '
                    'fetch.',
                    style: AppTextStyles.supporting,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A [SettingsRow] whose trailing control is a switch rather than a
/// chevron — tapping anywhere on the row toggles it.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String supporting;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.supporting,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(supporting, style: AppTextStyles.supporting),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
