import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/transaction.dart';

const _kTxnColumns = '''
  t.id, t.email_id, t.subject, t.amount, t.date, t.snippet, t.body,
  t.category_id, t.synced_to_sheet, c.name AS category_name,
  t.bank_code, t.bank_name, t.merchant_name, t.upi_id, t.reference_no,
  t.transaction_type, t.status, t.notes
''';

/// Local on-device database — the single source of truth for transactions
/// and categories. Google Sheets (see google_sheets_service.dart) is only
/// ever a one-way, append-only backup copy of what's stored here.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  Database? _db;

  /// Thin passthrough for read-only aggregate queries (see
  /// analytics_service.dart) — keeps ad hoc SQL out of the rest of the app
  /// while not requiring every aggregate to be hand-written as its own
  /// named method here.
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? arguments]) async {
    final db = await _database;
    return db.rawQuery(sql, arguments);
  }

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
      version: 2,
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
            synced_to_sheet INTEGER NOT NULL DEFAULT 0,
            bank_code TEXT,
            bank_name TEXT,
            merchant_name TEXT,
            upi_id TEXT,
            reference_no TEXT,
            transaction_type TEXT,
            status TEXT,
            notes TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final column in [
            'bank_code TEXT',
            'bank_name TEXT',
            'merchant_name TEXT',
            'upi_id TEXT',
            'reference_no TEXT',
            'transaction_type TEXT',
            'status TEXT',
            'notes TEXT',
          ]) {
            await db.execute('ALTER TABLE transactions ADD COLUMN $column');
          }
        }
      },
    );
  }

  /// Inserts newly-fetched transactions, ignoring ones already stored
  /// (matched by email_id). For an email already stored, the mail-derived
  /// fields are refreshed (in case parsing has since improved) but
  /// category, notes, and sync state are left untouched — those are only
  /// ever user-set.
  Future<void> insertNewTransactions(List<UpiTransaction> transactions) async {
    final db = await _database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.rawInsert('''
        INSERT INTO transactions (
          email_id, subject, amount, date, snippet, body,
          bank_code, bank_name, merchant_name, upi_id, reference_no, transaction_type, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(email_id) DO UPDATE SET
          subject = excluded.subject,
          amount = excluded.amount,
          date = excluded.date,
          snippet = excluded.snippet,
          body = excluded.body,
          bank_code = excluded.bank_code,
          bank_name = excluded.bank_name,
          merchant_name = excluded.merchant_name,
          upi_id = excluded.upi_id,
          reference_no = excluded.reference_no,
          transaction_type = excluded.transaction_type,
          status = excluded.status
      ''', [
        t.emailId,
        t.subject,
        t.amount,
        t.date?.toIso8601String(),
        t.snippet,
        t.body,
        t.bankCode,
        t.bankName,
        t.merchantName,
        t.upiId,
        t.referenceNo,
        t.transactionType,
        t.status,
      ]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<UpiTransaction>> getAllTransactions() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT $_kTxnColumns
      FROM transactions t
      LEFT JOIN category c ON c.id = t.category_id
      ORDER BY t.date DESC, t.id DESC
    ''');
    return rows.map(_transactionFromRow).toList();
  }

  Future<List<UpiTransaction>> getUnsyncedTransactions() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT $_kTxnColumns
      FROM transactions t
      LEFT JOIN category c ON c.id = t.category_id
      WHERE t.synced_to_sheet = 0
      ORDER BY t.date ASC, t.id ASC
    ''');
    return rows.map(_transactionFromRow).toList();
  }

  /// Count of transactions with no category assigned yet.
  Future<int> getUnlabelledCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Distinct bank codes present in the local data, e.g. ['HDFC', 'UBI'].
  Future<List<String>> getDistinctBankCodes() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT bank_code FROM transactions WHERE bank_code IS NOT NULL ORDER BY bank_code',
    );
    return rows.map((r) => r['bank_code'] as String).toList();
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

  Future<void> updateNotes(int transactionId, String notes) async {
    final db = await _database;
    await db.update(
      'transactions',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> deleteTransaction(int transactionId) async {
    final db = await _database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
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

  Future<void> deleteCategory(int categoryId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete('category', where: 'id = ?', whereArgs: [categoryId]);
    });
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
      bankCode: r['bank_code'] as String?,
      bankName: r['bank_name'] as String?,
      merchantName: r['merchant_name'] as String?,
      upiId: r['upi_id'] as String?,
      referenceNo: r['reference_no'] as String?,
      transactionType: r['transaction_type'] as String?,
      status: r['status'] as String?,
      notes: r['notes'] as String?,
    );
  }
}
