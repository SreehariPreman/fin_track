import '../models/analytics_filter.dart';
import '../models/analytics_models.dart';
import 'database_service.dart';

/// Read-only aggregate queries over the local transaction database, for
/// the Analytics tab. Every method takes the resolved [DateRange] plus the
/// non-date filter dimensions (bank/category/transaction type) — resolving
/// the month-selector-vs-Filters-override date logic is the caller's job
/// (see AnalyticsFilter.resolveDateRange).
class AnalyticsService {
  final _db = DatabaseService.instance;

  (String, List<Object?>) _whereClause(DateRange range, AnalyticsFilter filter) {
    final clauses = <String>['t.date >= ?', 't.date < ?', 't.amount IS NOT NULL'];
    final args = <Object?>[range.start.toIso8601String(), range.end.toIso8601String()];

    if (filter.bankCodes.isNotEmpty) {
      clauses.add('t.bank_code IN (${List.filled(filter.bankCodes.length, '?').join(',')})');
      args.addAll(filter.bankCodes);
    }
    if (filter.categoryIds.isNotEmpty) {
      clauses.add('t.category_id IN (${List.filled(filter.categoryIds.length, '?').join(',')})');
      args.addAll(filter.categoryIds);
    }
    if (filter.transactionTypes.isNotEmpty) {
      final wantsUpi = filter.transactionTypes.contains('UPI');
      final wantsOther = filter.transactionTypes.contains('Other');
      if (wantsUpi && !wantsOther) {
        clauses.add("UPPER(COALESCE(t.transaction_type, '')) = 'UPI'");
      } else if (wantsOther && !wantsUpi) {
        clauses.add("UPPER(COALESCE(t.transaction_type, '')) != 'UPI'");
      }
    }
    return (clauses.join(' AND '), args);
  }

  Future<double> totalSpend(DateRange range, AnalyticsFilter filter) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('SELECT SUM(t.amount) AS s FROM transactions t WHERE $where', args);
    return (rows.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<int> transactionCount(DateRange range, AnalyticsFilter filter) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('SELECT COUNT(*) AS c FROM transactions t WHERE $where', args);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<CategorySpend>> categoryBreakdown(DateRange range, AnalyticsFilter filter) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('''
      SELECT t.category_id, c.name AS category_name, SUM(t.amount) AS total, COUNT(*) AS cnt
      FROM transactions t LEFT JOIN category c ON c.id = t.category_id
      WHERE $where
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', args);
    return rows
        .map((r) => CategorySpend(
              categoryId: r['category_id'] as int?,
              categoryName: (r['category_name'] as String?) ?? 'Unlabelled',
              total: (r['total'] as num?)?.toDouble() ?? 0,
              count: r['cnt'] as int? ?? 0,
            ))
        .toList();
  }

  Future<List<BankSpend>> bankBreakdown(DateRange range, AnalyticsFilter filter) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('''
      SELECT t.bank_code, t.bank_name, SUM(t.amount) AS total, COUNT(*) AS cnt
      FROM transactions t
      WHERE $where AND t.bank_code IS NOT NULL
      GROUP BY t.bank_code
      ORDER BY total DESC
    ''', args);
    return rows
        .map((r) => BankSpend(
              bankCode: r['bank_code'] as String,
              bankName: (r['bank_name'] as String?) ?? (r['bank_code'] as String),
              total: (r['total'] as num?)?.toDouble() ?? 0,
              count: r['cnt'] as int? ?? 0,
            ))
        .toList();
  }

  /// Daily totals within [range] — the basis for the Overview trend
  /// sparkline and (bucketed further client-side) the Trends chart.
  Future<List<DailySpend>> dailySeries(DateRange range, AnalyticsFilter filter) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('''
      SELECT substr(t.date, 1, 10) AS day, SUM(t.amount) AS total
      FROM transactions t
      WHERE $where
      GROUP BY day
      ORDER BY day ASC
    ''', args);
    return rows
        .map((r) => DailySpend(
              date: DateTime.parse(r['day'] as String),
              total: (r['total'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  /// Per-bank daily series within [range], for the Banks tab's "Bank Wise
  /// Trend" line chart (one line per bank).
  Future<Map<String, List<DailySpend>>> dailySeriesPerBank(
    DateRange range,
    AnalyticsFilter filter,
  ) async {
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('''
      SELECT t.bank_code, substr(t.date, 1, 10) AS day, SUM(t.amount) AS total
      FROM transactions t
      WHERE $where AND t.bank_code IS NOT NULL
      GROUP BY t.bank_code, day
      ORDER BY day ASC
    ''', args);
    final result = <String, List<DailySpend>>{};
    for (final r in rows) {
      final bank = r['bank_code'] as String;
      result.putIfAbsent(bank, () => []).add(DailySpend(
            date: DateTime.parse(r['day'] as String),
            total: (r['total'] as num?)?.toDouble() ?? 0,
          ));
    }
    return result;
  }

  /// Total spend per calendar month for the trailing [monthsBack] months
  /// (inclusive of [uptoMonth]), broken down per bank — for the Banks
  /// tab's "Monthly Comparison" bar chart.
  Future<Map<String, List<MonthlySpend>>> monthlyTotalsPerBank(
    DateTime uptoMonth,
    int monthsBack,
    AnalyticsFilter filter,
  ) async {
    final start = DateTime(uptoMonth.year, uptoMonth.month - (monthsBack - 1), 1);
    final end = DateTime(uptoMonth.year, uptoMonth.month + 1, 1);
    final range = DateRange(start: start, end: end);
    final (where, args) = _whereClause(range, filter);
    final rows = await _db.query('''
      SELECT t.bank_code, substr(t.date, 1, 7) AS ym, SUM(t.amount) AS total
      FROM transactions t
      WHERE $where AND t.bank_code IS NOT NULL
      GROUP BY t.bank_code, ym
      ORDER BY ym ASC
    ''', args);
    final result = <String, List<MonthlySpend>>{};
    for (final r in rows) {
      final bank = r['bank_code'] as String;
      final parts = (r['ym'] as String).split('-');
      result.putIfAbsent(bank, () => []).add(MonthlySpend(
            month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
            total: (r['total'] as num?)?.toDouble() ?? 0,
          ));
    }
    return result;
  }

  Future<double> previousMonthTotal(DateTime selectedMonth, AnalyticsFilter filter) {
    final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    return totalSpend(DateRange.forMonth(prevMonth), filter);
  }
}
