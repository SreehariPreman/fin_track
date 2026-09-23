/// Parsing logic ported from the desktop app's email_service.py
/// (AMOUNT_PATTERNS, parse_date_from_body, extract_snippet, is_upi_related).
/// Kept behaviourally identical so HDFC UPI alerts parse the same way.
library;

class ParserService {
  static final List<RegExp> _amountPatterns = [
    RegExp(r'[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)\s+has\s+been\s+debited'),
    RegExp(r'debited?\s*(?:by|of)?\s*[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)'),
    RegExp(r'[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)'),
    RegExp(r'INR\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
    RegExp(r'₹\s*([\d,]+(?:\.\d{2})?)'),
    RegExp(r'amount\s*[:\s]*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
  ];

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  /// Extracts a numeric amount from email text (subject + body). Null if none found.
  static double? parseAmount(String text) {
    for (final pat in _amountPatterns) {
      final m = pat.firstMatch(text);
      if (m != null) {
        final raw = (m.groupCount >= 1 ? m.group(1) : m.group(0)) ?? '';
        final cleaned = raw.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
        final value = double.tryParse(cleaned);
        if (value != null) {
          return double.parse(value.toStringAsFixed(2));
        }
      }
    }
    return null;
  }

  /// Tries to find a date in the email body. HDFC uses DD-MM-YY.
  static DateTime? parseDateFromBody(String text) {
    // DD-MM-YY or DD/MM/YY (2 or 4 digit year)
    final numeric = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b').firstMatch(text);
    if (numeric != null) {
      try {
        final d = int.parse(numeric.group(1)!);
        final mo = int.parse(numeric.group(2)!);
        var y = int.parse(numeric.group(3)!);
        if (y < 100) y += 2000;
        if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12) {
          return DateTime(y, mo, d);
        }
      } catch (_) {
        // fall through to next pattern
      }
    }
    // DD Month YYYY
    final worded = RegExp(
      r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (worded != null) {
      try {
        final d = int.parse(worded.group(1)!);
        final moIdx = _months.indexOf(worded.group(2)!.toLowerCase());
        final y = int.parse(worded.group(3)!);
        if (moIdx >= 0) {
          return DateTime(y, moIdx + 1, d);
        }
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  /// Extracts a short description from an HDFC UPI body, e.g. the VPA/merchant name.
  static String extractSnippet(String body) {
    final m = RegExp(
      r'to\s+VPA\s+([^.]+?)(?:\s+on\s+\d{1,2}-\d{1,2}-\d{2,4}|\s*\.|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (m != null) {
      final snippet = m.group(1)!.trim().replaceAll('\n', ' ');
      return snippet.length > 200 ? snippet.substring(0, 200) : snippet;
    }
    final flat = body.replaceAll('\n', ' ').trim();
    return flat.length > 200 ? flat.substring(0, 200) : flat;
  }

  /// Heuristic: is this email about a UPI transaction?
  static bool isUpiRelated(String subject, String body) {
    final combined = ('$subject $body').toLowerCase();
    return combined.contains('upi') ||
        combined.contains('debited') ||
        combined.contains('payment');
  }
}
