import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sheet_sync_entry.dart';
import '../../services/database_service.dart';
import '../../services/google_sheets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

const _historyPageSize = 10;

/// Everything Google Sheets: which sheet is connected, syncing into it,
/// exporting a full copy to a new one, and the sync history.
class GoogleSheetScreen extends StatefulWidget {
  const GoogleSheetScreen({super.key});

  @override
  State<GoogleSheetScreen> createState() => _GoogleSheetScreenState();
}

class _GoogleSheetScreenState extends State<GoogleSheetScreen> {
  final _sheetsService = GoogleSheetsService();
  final _db = DatabaseService.instance;

  bool _loading = true;
  bool _connecting = false;
  bool _syncing = false;
  bool _exporting = false;

  GoogleSignInAccount? _account;
  SheetRef? _sheet;
  SheetSyncEntry? _lastSync;

  /// Newest-first history, grown a page at a time by "Load more".
  List<SheetSyncEntry> _history = [];
  int _historyTotal = 0;

  bool get _busy => _connecting || _syncing || _exporting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _account = await _sheetsService.signInSilently();
    } catch (_) {
      _account = null;
    }
    final sheet = await _sheetsService.getActiveSheet(refreshName: _account != null);
    final lastSync = await _db.getLastSuccessfulSheetSync();
    final total = await _db.getSheetSyncCount();
    final history = await _db.getSheetSyncHistory(limit: _historyPageSize);
    if (!mounted) return;
    setState(() {
      _sheet = sheet;
      _lastSync = lastSync;
      _historyTotal = total;
      _history = history;
      _loading = false;
    });
  }

  /// Re-reads the history from scratch, keeping however many pages were
  /// already expanded so a sync doesn't collapse the list back to ten.
  Future<void> _reloadHistory() async {
    final pageCount = _history.length < _historyPageSize ? _historyPageSize : _history.length;
    final lastSync = await _db.getLastSuccessfulSheetSync();
    final total = await _db.getSheetSyncCount();
    final history = await _db.getSheetSyncHistory(limit: pageCount);
    if (!mounted) return;
    setState(() {
      _lastSync = lastSync;
      _historyTotal = total;
      _history = history;
    });
  }

  Future<void> _loadMoreHistory() async {
    final more = await _db.getSheetSyncHistory(
      limit: _historyPageSize,
      offset: _history.length,
    );
    if (!mounted) return;
    setState(() => _history = [..._history, ...more]);
  }

  // -----------------------------------------------------------------
  // Connection
  // -----------------------------------------------------------------

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final account = await _sheetsService.signIn();
      if (!mounted) return;
      setState(() => _account = account);
      if (account != null) await _load();
    } catch (e) {
      _showError('Could not connect: ${_short(e)}');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google?'),
        content: const Text('Your sheet stays in Google Drive. Nothing is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _sheetsService.signOut();
    if (!mounted) return;
    setState(() => _account = null);
  }

  Future<void> _openSheet() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final opened = await launchUrl(Uri.parse(sheet.url), mode: LaunchMode.externalApplication);
    if (!opened) _showError('Could not open the sheet.');
  }

  /// Forgets the connected sheet so the next sync starts a fresh one, and
  /// clears the local sync flags so that sheet gets the full history.
  Future<void> _forgetSheet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use a different sheet?'),
        content: const Text(
          'The current sheet stays in Drive. The next sync creates a new one '
          'and writes your full history into it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _sheetsService.clearActiveSheet();
    await _db.markAllUnsynced();
    if (!mounted) return;
    setState(() => _sheet = null);
  }

  // -----------------------------------------------------------------
  // Syncing
  // -----------------------------------------------------------------

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final pending = await _db.getUnsyncedTransactions();
      if (pending.isEmpty && _sheet != null) {
        _showMessage('Already up to date.');
        return;
      }
      final result = await _sheetsService.syncToActiveSheet(pending);
      await _db.markSynced(pending.where((t) => t.id != null).map((t) => t.id!).toList());
      await _db.logSheetSync(
        kind: 'sync',
        status: 'success',
        rowCount: result.appended,
        skippedCount: result.skipped,
        spreadsheetId: result.sheet.id,
        spreadsheetName: result.sheet.name,
      );
      if (!mounted) return;
      setState(() => _sheet = result.sheet);
      _showMessage(result.appended == 0
          ? 'Already up to date.'
          : 'Added ${result.appended} row(s) to ${result.sheet.name}.');
    } catch (e) {
      await _db.logSheetSync(
        kind: 'sync',
        status: 'failed',
        rowCount: 0,
        spreadsheetId: _sheet?.id,
        spreadsheetName: _sheet?.name,
        message: _short(e),
      );
      _showError('Sync failed: ${_short(e)}');
    } finally {
      if (mounted) setState(() => _syncing = false);
      await _reloadHistory();
    }
  }

  Future<void> _exportToNewSheet() async {
    final request = await showDialog<_ExportRequest>(
      context: context,
      builder: (_) => const _ExportDialog(),
    );
    if (request == null) return;

    setState(() => _exporting = true);
    try {
      final all = await _db.getAllTransactionsForExport();
      final result = await _sheetsService.exportToNewSheet(
        title: request.name,
        transactions: all,
      );
      if (request.makeActive) {
        await _sheetsService.setActiveSheet(result.sheet);
        // The new sheet now holds everything, so nothing is pending for it.
        await _db.markAllSynced();
        if (mounted) setState(() => _sheet = result.sheet);
      }
      await _db.logSheetSync(
        kind: 'export',
        status: 'success',
        rowCount: result.appended,
        skippedCount: result.skipped,
        spreadsheetId: result.sheet.id,
        spreadsheetName: result.sheet.name,
      );
      if (!mounted) return;
      _showMessage(
        'Exported ${result.appended} row(s) to ${result.sheet.name}.',
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => launchUrl(Uri.parse(result.sheet.url), mode: LaunchMode.externalApplication),
        ),
      );
    } catch (e) {
      await _db.logSheetSync(
        kind: 'export',
        status: 'failed',
        rowCount: 0,
        spreadsheetName: request.name,
        message: _short(e),
      );
      _showError('Export failed: ${_short(e)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
      await _reloadHistory();
    }
  }

  // -----------------------------------------------------------------

  /// API errors arrive as a whole JSON body — keep the snackbar readable.
  String _short(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 140 ? text : '${text.substring(0, 140)}…';
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), action: action),
    );
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sheet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _connectionCard(),
                if (_account != null) ...[
                  const SizedBox(height: 16),
                  _actionsCard(),
                ],
                const SizedBox(height: 16),
                _historyCard(),
              ],
            ),
    );
  }

  Widget _connectionCard() {
    if (_account == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.linkBreak, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text('Not connected', style: AppTextStyles.sectionTitle),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              icon: _connecting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(PhosphorIconsRegular.signIn, size: 20),
              label: const Text('Connect to Google Sheet'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      );
    }

    final sheet = _sheet;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsFill.checkCircle, size: 20, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sheet?.name ?? 'No sheet yet',
                  style: AppTextStyles.sectionTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(PhosphorIconsRegular.dotsThreeVertical, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'forget') _forgetSheet();
                  if (value == 'disconnect') _disconnect();
                },
                itemBuilder: (_) => [
                  if (sheet != null)
                    const PopupMenuItem(value: 'forget', child: Text('Use a different sheet')),
                  const PopupMenuItem(value: 'disconnect', child: Text('Disconnect Google')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(_account!.email, style: AppTextStyles.supporting),
          ),
          if (sheet != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openSheet,
                icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 18),
                label: const Text('Open in Google Sheets'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: Text('Sync creates one.', style: AppTextStyles.supporting),
            ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(PhosphorIconsRegular.cloudArrowUp, size: 20),
            label: Text(_syncing ? 'Syncing…' : 'Sync now'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _exportToNewSheet,
            icon: _exporting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(PhosphorIconsRegular.filePlus, size: 20),
            label: Text(_exporting ? 'Exporting…' : 'Export to a new sheet'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          Text(
            'Sync adds only new transactions to the sheet above. '
            'Export writes your full history into a fresh sheet. '
            'Rows are matched on Email ID, so nothing is ever overwritten or duplicated.',
            style: AppTextStyles.supporting,
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    final hasMore = _history.length < _historyTotal;
    final last = _lastSync;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sync history', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text(
            last == null
                ? 'Not synced yet'
                : 'Last synced ${DateFormat('dd MMM yyyy · h:mm a').format(last.syncedAt)}',
            style: AppTextStyles.bodySecondary,
          ),
          if (_history.isEmpty)
            const SizedBox(height: 8)
          else ...[
            const SizedBox(height: 8),
            for (final entry in _history) ...[
              const Divider(height: 1),
              _HistoryRow(entry: entry),
            ],
          ],
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: TextButton(
                onPressed: _loadMoreHistory,
                child: const Text('Load more'),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SheetSyncEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final failed = !entry.isSuccess;
    final color = failed
        ? AppColors.error
        : (entry.isExport ? AppColors.primary : AppColors.success);
    final icon = failed
        ? PhosphorIconsRegular.warningCircle
        : (entry.isExport ? PhosphorIconsRegular.filePlus : PhosphorIconsRegular.cloudCheck);

    final String title;
    if (failed) {
      title = entry.isExport ? 'Export failed' : 'Sync failed';
    } else if (entry.isExport) {
      title = 'Exported ${entry.rowCount} row(s)';
    } else if (entry.rowCount == 0) {
      title = 'No new rows';
    } else {
      title = 'Synced ${entry.rowCount} row(s)';
    }

    final details = <String>[
      DateFormat('dd MMM yyyy · h:mm a').format(entry.syncedAt),
      if (entry.spreadsheetName != null && entry.spreadsheetName!.isNotEmpty) entry.spreadsheetName!,
      if (!failed && entry.skippedCount > 0) '${entry.skippedCount} already there',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: AppTextStyles.supporting),
                if (failed && entry.message != null && entry.message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.supporting.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportRequest {
  final String name;

  /// Whether future syncs should go to the newly-created sheet instead of
  /// the currently connected one.
  final bool makeActive;

  _ExportRequest({required this.name, required this.makeActive});
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: 'Fin Track ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
  );
  bool _makeActive = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_ExportRequest(name: name, makeActive: _makeActive));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export to a new sheet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Sheet name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text('Your full history is written into it.', style: AppTextStyles.supporting),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _makeActive,
            onChanged: (value) => setState(() => _makeActive = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text('Sync to this one from now on', style: AppTextStyles.bodySecondary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Export')),
      ],
    );
  }
}
