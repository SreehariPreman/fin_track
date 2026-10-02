import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/google_sheets_service.dart';
import '../services/sync_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_group.dart';
import 'settings/about_screen.dart';
import 'settings/categories_screen.dart';
import 'settings/gmail_account_screen.dart';
import 'settings/google_sheet_screen.dart';
import 'settings/local_storage_screen.dart';
import 'settings/sync_settings_screen.dart';

/// Settings as a grouped list of destinations. Each row states what it is
/// and its current value; the detail belongs on the screen it opens, not
/// here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _credentialsService = CredentialsService();
  final _sheetsService = GoogleSheetsService();
  final _syncPrefs = SyncPreferences();
  final _db = DatabaseService.instance;

  String? _email;
  String? _sheetName;
  int _categoryCount = 0;
  String _syncSummary = '';
  String _storageSummary = '';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-read on every return from a sub-screen, so each row's value stays
  /// honest after it's been changed there.
  Future<void> _load() async {
    String? email;
    try {
      email = await _credentialsService.readEmail();
    } catch (_) {
      email = null;
    }

    // Never hits the network — a stale name beats a slow Settings screen.
    final sheet = await _sheetsService.getActiveSheet(refreshName: false);
    final categories = await _db.getCategories();
    final stats = await _db.getLocalStorageStats();
    final syncEnabled = await _syncPrefs.isEnabled();
    final interval = await _syncPrefs.intervalMinutes();
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;
    setState(() {
      _email = email;
      _sheetName = sheet?.name;
      _categoryCount = categories.length;
      _syncSummary = syncEnabled ? SyncPreferences.describeInterval(interval) : 'Off';
      _storageSummary = '${stats.transactions} transactions · ${stats.formattedSize}';
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = (_email ?? '').isNotEmpty;
    final hasSheet = (_sheetName ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        titleSpacing: AppTheme.gutter,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
        children: [
          SettingsGroup(
            title: 'Accounts',
            children: [
              SettingsRow(
                icon: PhosphorIconsRegular.envelopeSimple,
                label: 'Gmail Account',
                supporting: hasEmail ? _email : 'Not connected',
                accent: hasEmail ? null : AppColors.warning,
                onTap: () => _open(const GmailAccountScreen()),
              ),
              SettingsRow(
                icon: PhosphorIconsRegular.table,
                label: 'Google Sheets',
                supporting: hasSheet ? _sheetName : 'Not connected',
                accent: hasSheet ? null : AppColors.warning,
                onTap: () => _open(const GoogleSheetScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sectionGap),
          SettingsGroup(
            title: 'App Preferences',
            children: [
              SettingsRow(
                icon: PhosphorIconsRegular.tag,
                label: 'Categories',
                supporting: _categoryCount == 0
                    ? 'None yet'
                    : '$_categoryCount ${_categoryCount == 1 ? 'category' : 'categories'}',
                onTap: () => _open(const CategoriesScreen()),
              ),
              SettingsRow(
                icon: PhosphorIconsRegular.arrowsClockwise,
                label: 'Sync Settings',
                supporting: _syncSummary,
                onTap: () => _open(const SyncSettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sectionGap),
          SettingsGroup(
            title: 'Data & Storage',
            children: [
              SettingsRow(
                icon: PhosphorIconsRegular.database,
                label: 'Local Storage',
                supporting: _storageSummary,
                onTap: () => _open(const LocalStorageScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sectionGap),
          SettingsGroup(
            title: 'About',
            children: [
              SettingsRow(
                icon: PhosphorIconsRegular.info,
                label: 'Version',
                trailingText: _version,
                onTap: () => _open(const AboutScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
