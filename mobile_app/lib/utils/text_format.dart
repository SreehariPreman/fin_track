/// Merchant names arrive from bank alert emails as raw, shouty strings —
/// "AMRITHA PRASANNA K", "ORBGEN TECHNOLOGIES PRIVATE LIMITED DISTRICT
/// MOVIE UPI". Rendering those verbatim is most of why the list looked
/// machine-generated, so they get cased for display only; the stored value
/// is left untouched.
class TextFormat {
  TextFormat._();

  /// Tokens that should stay upper-case when title-casing.
  static const _keepUpper = {
    'UPI', 'ATM', 'NEFT', 'IMPS', 'RTGS', 'EMI', 'POS', 'GST', 'OTP',
    'HDFC', 'UBI', 'SBI', 'ICICI', 'AXIS', 'IDFC', 'PVR', 'KFC', 'LLP',
    'INC', 'LLC', 'JSW', 'TVS', 'BPCL', 'HPCL', 'IOCL', 'IRCTC', 'KSEB',
  };

  /// Corporate suffixes that add nothing in a list row.
  static final _noise = RegExp(
    r'\b(PRIVATE|PVT\.?|LIMITED|LTD\.?|TECHNOLOGIES|TECHNOLOGY|SOLUTIONS|ENTERPRISES|INDIA)\b',
    caseSensitive: false,
  );

  /// Title-cases a name that is entirely (or almost entirely) upper-case,
  /// and leaves mixed-case names alone — a merchant that already writes
  /// itself "McDonald's" or "bigbasket" knows better than we do.
  static String merchant(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return s;

    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return s;
    final upperRatio =
        letters.split('').where((c) => c == c.toUpperCase()).length / letters.length;
    if (upperRatio < 0.8) return s;

    s = s.replaceAll(_noise, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return raw.trim();

    return s
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final bare = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
          if (_keepUpper.contains(bare.toUpperCase())) return word.toUpperCase();
          // A lone letter is almost always an initial ("BABU K A").
          if (bare.length == 1) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
