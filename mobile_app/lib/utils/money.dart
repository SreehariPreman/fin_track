import 'package:intl/intl.dart';

/// Currency formatting, in one place.
///
/// Uses the en_IN locale so grouping follows the lakh/crore convention
/// (₹1,25,000, not ₹125,000) — the previous `toStringAsFixed(0)` produced
/// unpunctuated runs like ₹125000 that are genuinely hard to read at a
/// glance, which is the whole job of the hero number.
class Money {
  Money._();

  static final _whole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _precise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Rounded — for totals, summaries and chart labels.
  static String whole(double? value) => value == null ? '—' : _whole.format(value);

  /// Exact — for a single transaction, where the paise matter.
  static String precise(double? value) => value == null ? '—' : _precise.format(value);

  /// Compact axis/label form: ₹1.2k, ₹3.4L.
  static String compact(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}k';
    return '₹${value.toStringAsFixed(0)}';
  }
}
