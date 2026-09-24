import 'package:flutter/material.dart';

/// Fields extracted from one bank alert email. Any field can be null if
/// the email didn't contain it (or didn't match the expected format) —
/// screens should hide/fallback rather than assume everything is present.
class ParsedTransactionFields {
  final double? amount;
  final DateTime? date;
  final String? merchantName;
  final String? upiId;
  final String? referenceNo;
  final String? transactionType;
  final String? status;
  final String? accountMasked;

  const ParsedTransactionFields({
    this.amount,
    this.date,
    this.merchantName,
    this.upiId,
    this.referenceNo,
    this.transactionType,
    this.status,
    this.accountMasked,
  });
}

typedef BankParser = ParsedTransactionFields Function(String subject, String body);

/// One supported bank's sender address + how to parse its alert emails.
/// Add a new bank by adding a profile here — nothing else needs to change
/// for it to be picked up by fetch/list/filtering.
class BankProfile {
  final String code;
  final String name;
  final String senderEmail;
  final Color badgeColor;
  final BankParser _parse;

  const BankProfile({
    required this.code,
    required this.name,
    required this.senderEmail,
    required this.badgeColor,
    required BankParser parse,
  }) : _parse = parse;

  bool matchesSender(String fromEmail) =>
      fromEmail.toLowerCase().contains(senderEmail.toLowerCase());

  ParsedTransactionFields parse(String subject, String body) => _parse(subject, body);
}

double? _parseAmount(RegExp pattern, String text) {
  final m = pattern.firstMatch(text);
  if (m == null || m.groupCount < 1) return null;
  final raw = (m.group(1) ?? '').replaceAll(',', '');
  return double.tryParse(raw);
}

/// Extracts several "Label : value" fields from [body], where a value is
/// bounded by wherever the *next* label (from [labelsInOrder]) starts, or
/// the end of the string for the last one — not by a newline. Real emails
/// often lose their line breaks somewhere in HTML-to-text conversion, so
/// anchoring to the next known label (rather than "until end of line") is
/// what actually keeps each field from swallowing the rest of the email.
/// Common openers for the boilerplate safety notice that trails most bank
/// alert emails — used as a fallback stop for whichever field happens to
/// be last, so it doesn't run on to the end of that boilerplate too.
const _trailingBoilerplateStops = [
  'If you have not',
  'If you did not',
  'Need Help',
  'Warm [Rr]egards',
  'Safe Banking',
];

Map<String, String?> _extractLabeledFields(String body, List<String> labelsInOrder) {
  final result = <String, String?>{};
  for (var i = 0; i < labelsInOrder.length; i++) {
    final label = labelsInOrder[i];
    final laterLabels = labelsInOrder.sublist(i + 1).map(RegExp.escape).join('|');
    final stops = [
      if (laterLabels.isNotEmpty) '(?:(?:\\d+\\.)?\\s*(?:$laterLabels)\\s*:)',
      r'\n',
      ..._trailingBoilerplateStops,
    ];
    final boundary = '(?:${stops.join('|')})|\$';
    final pattern = RegExp(
      '${RegExp.escape(label)}\\s*:\\s*(.+?)(?=$boundary)',
      caseSensitive: false,
      dotAll: true,
    );
    result[label] = pattern.firstMatch(body)?.group(1)?.trim();
  }
  return result;
}

final BankProfile hdfcBank = BankProfile(
  code: 'HDFC',
  name: 'HDFC Bank',
  senderEmail: 'alerts@hdfcbank.bank.in',
  badgeColor: const Color(0xFF1E3A8A),
  parse: (subject, body) {
    // HDFC sends at least two templates: a debit alert ("Rs.X is debited
    // ... towards VPA <id> (<name>) on DD-MM-YY") and a credit notification
    // ("Rs.X has been successfully credited ... Sender: NAME (VPA: id)
    // ... Date: DD-MM-YY"). Both are handled here.
    final amount = _parseAmount(
      RegExp(
        r'Rs\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:is\s+debited|has\s+been\s+(?:successfully\s+)?credited)',
        caseSensitive: false,
      ),
      body,
    );

    DateTime? date;
    final dateMatch =
        RegExp(r'(?:\bon\s+|\bDate:?\s*)(\d{1,2})-(\d{1,2})-(\d{2,4})', caseSensitive: false)
            .firstMatch(body);
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1)!);
      final mo = int.tryParse(dateMatch.group(2)!);
      var y = int.tryParse(dateMatch.group(3)!);
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        date = DateTime(y, mo, d);
      }
    }

    String? merchantName;
    String? upiId;
    final debitMatch = RegExp(r'towards\s+VPA\s+(\S+)\s*\(([^)]+)\)', caseSensitive: false)
        .firstMatch(body);
    if (debitMatch != null) {
      upiId = debitMatch.group(1)?.trim();
      merchantName = debitMatch.group(2)?.trim();
    } else {
      final creditMatch =
          RegExp(r'Sender:\s*([^(]+?)\s*\(\s*VPA:?\s*([^)]+)\)', caseSensitive: false)
              .firstMatch(body);
      if (creditMatch != null) {
        merchantName = creditMatch.group(1)?.trim();
        upiId = creditMatch.group(2)?.trim();
      }
    }

    final refMatch = RegExp(
      r'UPI\s*(?:transaction\s*)?reference\s*no\.?:?\s*(\w+)',
      caseSensitive: false,
    ).firstMatch(body);
    final accountMatch =
        RegExp(r'account ending\s*(?:in\s*)?(\w+)', caseSensitive: false).firstMatch(body);

    return ParsedTransactionFields(
      amount: amount,
      date: date,
      merchantName: merchantName,
      upiId: upiId,
      referenceNo: refMatch?.group(1),
      transactionType: 'UPI',
      status: 'Success',
      accountMasked: accountMatch?.group(1),
    );
  },
);

const _unionBankLabels = [
  'Payee Name',
  'Amount',
  'Channel',
  'Transaction ID/RRN',
  'Transaction Status',
  'Transaction Date and Time',
  'Debit Account Number',
];

final BankProfile unionBank = BankProfile(
  code: 'UBI',
  name: 'Union Bank',
  senderEmail: 'noreplyubi-txn@ubi.bank.in',
  badgeColor: const Color(0xFF7F1D1D),
  parse: (subject, body) {
    final fields = _extractLabeledFields(body, _unionBankLabels);

    final amountText = fields['Amount'];
    final amount = amountText != null
        ? _parseAmount(RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false), amountText)
        : null;

    DateTime? date;
    final dateText = fields['Transaction Date and Time'];
    if (dateText != null) {
      final dateMatch = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})')
          .firstMatch(dateText);
      if (dateMatch != null) {
        final parts = dateMatch.groups([1, 2, 3, 4, 5, 6]).map((s) => int.tryParse(s ?? '')).toList();
        if (parts.every((p) => p != null)) {
          date = DateTime(parts[2]!, parts[1]!, parts[0]!, parts[3]!, parts[4]!, parts[5]!);
        }
      }
    }

    return ParsedTransactionFields(
      amount: amount,
      date: date,
      merchantName: fields['Payee Name'],
      upiId: null,
      referenceNo: fields['Transaction ID/RRN'],
      transactionType: fields['Channel'],
      status: fields['Transaction Status'],
      accountMasked: fields['Debit Account Number'],
    );
  },
);

final List<BankProfile> bankProfiles = [hdfcBank, unionBank];

/// Finds the bank profile whose sender address matches, or null if this
/// email isn't from a bank we recognise (it should be skipped).
BankProfile? bankProfileForSender(String fromEmail) {
  for (final profile in bankProfiles) {
    if (profile.matchesSender(fromEmail)) return profile;
  }
  return null;
}

BankProfile? bankProfileForCode(String? code) {
  if (code == null) return null;
  for (final profile in bankProfiles) {
    if (profile.code == code) return profile;
  }
  return null;
}
