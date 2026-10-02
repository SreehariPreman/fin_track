import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/database_service.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/settings_group.dart';

/// What the app is keeping on this device — the local SQLite database is
/// the source of truth, so this is the whole of your data.
class LocalStorageScreen extends StatefulWidget {
  const LocalStorageScreen({super.key});

  @override
  State<LocalStorageScreen> createState() => _LocalStorageScreenState();
}

class _LocalStorageScreenState extends State<LocalStorageScreen> {
  final _db = DatabaseService.instance;
  LocalStorageStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _db.getLocalStorageStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  String _date(DateTime? value) =>
      value == null ? '—' : DateFormat('dd MMM yyyy').format(value);

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Local Storage')),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      Text(stats.formattedSize, style: AppTextStyles.display),
                      const SizedBox(height: 6),
                      Text(
                        '${stats.transactions} transaction${stats.transactions == 1 ? '' : 's'} '
                        'on this device',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: 'Contents',
                  children: [
                    SettingsStatRow(label: 'Transactions', value: '${stats.transactions}'),
                    SettingsStatRow(label: 'Categories', value: '${stats.categories}'),
                    SettingsStatRow(label: 'Unlabelled', value: '${stats.unlabelled}'),
                    SettingsStatRow(
                      label: 'Backed up to Sheets',
                      value: '${stats.synced} of ${stats.transactions}',
                    ),
                    SettingsStatRow(label: 'Sync runs recorded', value: '${stats.syncRuns}'),
                  ],
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: 'Date range',
                  children: [
                    SettingsStatRow(label: 'Oldest', value: _date(stats.oldest)),
                    SettingsStatRow(label: 'Newest', value: _date(stats.newest)),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Everything lives in one SQLite file in the app\'s private '
                    'storage. Uninstalling the app deletes it — a Google Sheet '
                    'export is the only copy that survives.',
                    style: AppTextStyles.supporting,
                  ),
                ),
              ],
            ),
    );
  }
}
