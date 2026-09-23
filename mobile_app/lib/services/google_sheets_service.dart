import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

/// One-way, append-only backup of the local database to a Google Sheet.
/// The local SQLite database (see database_service.dart) is always the
/// source of truth; this service only ever pushes rows outward, never
/// reads them back or overwrites anything.
class GoogleSheetsService {
  static const _sheetTabName = 'Transactions';
  static const _spreadsheetIdPrefKey = 'sheets_spreadsheet_id';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/spreadsheets'],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() => _googleSignIn.signInSilently();

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.disconnect();

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

  Future<String> _getOrCreateSpreadsheetId(Map<String, String> headers) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_spreadsheetIdPrefKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final response = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: headers,
      body: jsonEncode({
        'properties': {'title': 'Fin Track Transactions'},
        'sheets': [
          {
            'properties': {'title': _sheetTabName},
            'data': [
              {
                'startRow': 0,
                'startColumn': 0,
                'rowData': [
                  {
                    'values': [
                      'Date',
                      'Amount',
                      'Category',
                      'Description',
                      'Email ID',
                    ]
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
    final id = jsonDecode(response.body)['spreadsheetId'] as String;
    await prefs.setString(_spreadsheetIdPrefKey, id);
    return id;
  }

  /// Appends [transactions] as new rows. Returns the spreadsheet id used,
  /// so callers can show/open it if needed.
  Future<String> appendTransactions(List<UpiTransaction> transactions) async {
    final headers = await _authHeaders();
    final spreadsheetId = await _getOrCreateSpreadsheetId(headers);

    if (transactions.isEmpty) return spreadsheetId;

    final values = transactions
        .map((t) => [
              t.date?.toIso8601String().substring(0, 10) ?? '',
              t.amount?.toStringAsFixed(2) ?? '',
              t.categoryName ?? 'Uncategorised',
              t.snippet,
              t.emailId,
            ])
        .toList();

    final range = Uri.encodeComponent('$_sheetTabName!A:E');
    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$range:append'
        '?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      ),
      headers: headers,
      body: jsonEncode({'values': values}),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not append to spreadsheet: ${response.statusCode} ${response.body}');
    }

    return spreadsheetId;
  }
}
