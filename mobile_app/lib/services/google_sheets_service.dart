import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

/// The spreadsheet the app currently syncs into.
class SheetRef {
  final String id;
  final String name;

  SheetRef({required this.id, required this.name});

  String get url => 'https://docs.google.com/spreadsheets/d/$id/edit';
}

/// Outcome of one write to a spreadsheet.
class SheetWriteResult {
  final SheetRef sheet;

  /// Rows actually appended.
  final int appended;

  /// Rows the sheet already had (matched on Email ID) and that were
  /// therefore left alone rather than written a second time.
  final int skipped;

  SheetWriteResult({required this.sheet, required this.appended, required this.skipped});
}

/// One-way, append-only backup of the local database to a Google Sheet.
///
/// The local SQLite database (see database_service.dart) is always the
/// source of truth; this service only ever *adds* rows to a sheet. Nothing
/// is ever overwritten, cleared, or read back into the app.
///
/// How a row is identified: every row carries the transaction's `Email ID`
/// (column E) — the IMAP message id, which is unique and stable per
/// transaction. Two things use it:
///
///  * Locally, `transactions.synced_to_sheet` marks what has already gone
///    to the connected sheet, so a normal sync only sends what's new.
///  * Before appending, the sheet's existing Email ID column is read back
///    and any transaction already present is skipped. So even if the local
///    flags and the sheet disagree (a restored backup, a sheet edited by
///    hand, a sync that half-failed), syncing again appends only the
///    genuinely missing rows instead of duplicating.
///
/// Exporting to a *new* sheet is a separate operation: the new sheet has
/// no Email IDs in it yet, so it receives the full history — that's the
/// "give someone a copy" path.
class GoogleSheetsService {
  static const _sheetTabName = 'Transactions';
  static const _spreadsheetIdPrefKey = 'sheets_spreadsheet_id';
  static const _spreadsheetNamePrefKey = 'sheets_spreadsheet_name';

  static const _headerRow = ['Date', 'Amount', 'Category', 'Description', 'Email ID'];

  /// Column holding the Email ID, i.e. the per-row unique key.
  static const _emailIdColumnRange = '$_sheetTabName!E2:E';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/spreadsheets'],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() => _googleSignIn.signInSilently();

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.disconnect();

  // ---------------------------------------------------------------------
  // Which sheet we're connected to
  // ---------------------------------------------------------------------

  /// The spreadsheet the app syncs into, or null if none has been created
  /// or chosen yet. Never creates one.
  ///
  /// When signed in, the title is refreshed from Drive first — so a sheet
  /// renamed in Google shows its real name here rather than a stale one.
  Future<SheetRef?> getActiveSheet({bool refreshName = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_spreadsheetIdPrefKey);
    if (id == null || id.isEmpty) return null;

    final storedName = prefs.getString(_spreadsheetNamePrefKey) ?? 'Fin Track Transactions';
    if (!refreshName) return SheetRef(id: id, name: storedName);

    try {
      final liveName = await _fetchSpreadsheetTitle(id);
      if (liveName != null && liveName != storedName) {
        await prefs.setString(_spreadsheetNamePrefKey, liveName);
        return SheetRef(id: id, name: liveName);
      }
    } catch (_) {
      // Offline / not signed in — the stored name is good enough.
    }
    return SheetRef(id: id, name: storedName);
  }

  Future<void> setActiveSheet(SheetRef sheet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spreadsheetIdPrefKey, sheet.id);
    await prefs.setString(_spreadsheetNamePrefKey, sheet.name);
  }

  /// Forgets the connected sheet (the sheet itself is left untouched in
  /// Drive) so the next sync starts a fresh one.
  Future<void> clearActiveSheet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spreadsheetIdPrefKey);
    await prefs.remove(_spreadsheetNamePrefKey);
  }

  // ---------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------

  /// Appends everything in [transactions] that the connected sheet doesn't
  /// already have. Creates the sheet on first use, named [defaultName].
  Future<SheetWriteResult> syncToActiveSheet(
    List<UpiTransaction> transactions, {
    String defaultName = 'Fin Track Transactions',
  }) async {
    final headers = await _authHeaders();
    var sheet = await getActiveSheet(refreshName: false);
    sheet ??= await _createSpreadsheet(headers, defaultName);
    await setActiveSheet(sheet);
    return _appendMissing(headers, sheet, transactions);
  }

  /// Creates a brand-new spreadsheet called [title] and writes
  /// [transactions] into it — the "export a copy to send to someone" path.
  /// The connected sheet is left as it is; switching to the new one is the
  /// caller's decision (see [setActiveSheet]).
  Future<SheetWriteResult> exportToNewSheet({
    required String title,
    required List<UpiTransaction> transactions,
  }) async {
    final headers = await _authHeaders();
    final sheet = await _createSpreadsheet(headers, title);
    // A new sheet holds no Email IDs, so nothing can be skipped — but go
    // through the same path so the row shape stays identical.
    return _appendMissing(headers, sheet, transactions);
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  Future<Map<String, String>> _authHeaders() async {
    final account = currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      throw StateError('Not signed in to Google.');
    }
    final headers = await account.authHeaders;
    return {
      ...headers,
      'Content-Type': 'application/json',
    };
  }

  Future<String?> _fetchSpreadsheetTitle(String spreadsheetId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId'
        '?fields=properties.title',
      ),
      headers: headers,
    );
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body)['properties']?['title'] as String?;
  }

  Future<SheetRef> _createSpreadsheet(Map<String, String> headers, String title) async {
    final response = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: headers,
      body: jsonEncode({
        'properties': {'title': title},
        'sheets': [
          {
            'properties': {'title': _sheetTabName},
            'data': [
              {
                'startRow': 0,
                'startColumn': 0,
                'rowData': [
                  {
                    'values': _headerRow
                        .map((h) => {
                              'userEnteredValue': {'stringValue': h}
                            })
                        .toList(),
                  },
                ],
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not create spreadsheet: ${response.statusCode} ${response.body}');
    }
    final body = jsonDecode(response.body);
    return SheetRef(
      id: body['spreadsheetId'] as String,
      name: (body['properties']?['title'] as String?) ?? title,
    );
  }

  /// The Email IDs already written to [spreadsheetId] — the sheet's own
  /// record of what it holds, used to make appending idempotent.
  Future<Set<String>> _existingEmailIds(
    Map<String, String> headers,
    String spreadsheetId,
  ) async {
    final range = Uri.encodeComponent(_emailIdColumnRange);
    final response = await http.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$range'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Could not read the spreadsheet: ${response.statusCode} ${response.body}');
    }
    final values = jsonDecode(response.body)['values'] as List<dynamic>?;
    if (values == null) return {};
    return values
        .map((row) => (row is List && row.isNotEmpty) ? row.first.toString() : '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<SheetWriteResult> _appendMissing(
    Map<String, String> headers,
    SheetRef sheet,
    List<UpiTransaction> transactions,
  ) async {
    if (transactions.isEmpty) {
      return SheetWriteResult(sheet: sheet, appended: 0, skipped: 0);
    }

    final alreadyThere = await _existingEmailIds(headers, sheet.id);
    final toWrite = transactions.where((t) => !alreadyThere.contains(t.emailId)).toList();
    final skipped = transactions.length - toWrite.length;

    if (toWrite.isEmpty) {
      return SheetWriteResult(sheet: sheet, appended: 0, skipped: skipped);
    }

    final values = toWrite.map(_rowFor).toList();
    final range = Uri.encodeComponent('$_sheetTabName!A:E');
    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/${sheet.id}/values/$range:append'
        '?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      ),
      headers: headers,
      body: jsonEncode({'values': values}),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not append to spreadsheet: ${response.statusCode} ${response.body}');
    }

    return SheetWriteResult(sheet: sheet, appended: toWrite.length, skipped: skipped);
  }

  List<String> _rowFor(UpiTransaction t) => [
        t.date?.toIso8601String().substring(0, 10) ?? '',
        t.amount?.toStringAsFixed(2) ?? '',
        t.categoryName ?? 'Uncategorised',
        t.snippet,
        t.emailId,
      ];
}
