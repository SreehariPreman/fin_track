import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/transaction.dart';

/// Local on-device database — the single source of truth for transactions
/// and categories. Google Sheets (see google_sheets_service.dart) is only
/// ever a one-way, append-only backup copy of what's stored here.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fin_track.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE category (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email_id TEXT UNIQUE NOT NULL,
            subject TEXT,
            amount REAL,
            date TEXT,
            snippet TEXT,
            body TEXT,
            category_id INTEGER REFERENCES category(id),
            synced_to_sheet INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Inserts newly-fetched transactions, ignoring ones already stored
  /// (matched by email_id). Existing rows — including their category and
  /// sync state — are left untouched.
  Future<void> insertNewTransactions(List<UpiTransaction> transactions) async {
    final db = await _database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert(
        'transactions',
        {
          'email_id': t.emailId,
          'subject': t.subject,
          'amount': t.amount,
          'date': t.date?.toIso8601String(),
          'snippet': t.snippet,
          'body': t.body,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<UpiTransaction>> getAllTransactions() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.id, t.email_id, t.subject, t.amount, t.date, t.snippet, t.body,
             t.category_id, t.synced_to_sheet, c.name AS category_name
      FROM transactions t
      LEFT JOIN category c ON c.id = t.category_id
      ORDER BY t.date DESC, t.id DESC
    ''');
    return rows.map(_transactionFromRow).toList();
  }

  Future<List<UpiTransaction>> getUnsyncedTransactions() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.id, t.email_id, t.subject, t.amount, t.date, t.snippet, t.body,
             t.category_id, t.synced_to_sheet, c.name AS category_name
      FROM transactions t
      LEFT JOIN category c ON c.id = t.category_id
      WHERE t.synced_to_sheet = 0
      ORDER BY t.date ASC, t.id ASC
    ''');
    return rows.map(_transactionFromRow).toList();
  }

  Future<void> markSynced(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(transactionIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE transactions SET synced_to_sheet = 1 WHERE id IN ($placeholders)',
      transactionIds,
    );
  }

  Future<void> assignCategory(int transactionId, int? categoryId) async {
    final db = await _database;
    await db.update(
      'transactions',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<List<Category>> getCategories() async {
    final db = await _database;
    final rows = await db.query('category', orderBy: 'name');
    return rows.map((r) => Category(id: r['id'] as int, name: r['name'] as String)).toList();
  }

  Future<Category> createCategory(String name) async {
    final db = await _database;
    final id = await db.insert(
      'category',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return Category(id: id, name: name);
  }

  UpiTransaction _transactionFromRow(Map<String, Object?> r) {
    return UpiTransaction(
      id: r['id'] as int,
      emailId: r['email_id'] as String,
      subject: (r['subject'] as String?) ?? '',
      amount: (r['amount'] as num?)?.toDouble(),
      date: r['date'] != null ? DateTime.tryParse(r['date'] as String) : null,
      snippet: (r['snippet'] as String?) ?? '',
      body: (r['body'] as String?) ?? '',
      categoryId: r['category_id'] as int?,
      categoryName: r['category_name'] as String?,
      syncedToSheet: (r['synced_to_sheet'] as int? ?? 0) == 1,
    );
  }
}
