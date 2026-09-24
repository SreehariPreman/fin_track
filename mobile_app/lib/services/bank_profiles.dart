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

final BankProfile hdfcBank = BankProfile(
  code: 'HDFC',
  name: 'HDFC Bank',
  senderEmail: 'alerts@hdfcbank.bank.in',
  badgeColor: const Color(0xFF1E3A8A),
  parse: (subject, body) {
    final amount = _parseAmount(
      RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{2})?)\s+is\s+debited', caseSensitive: false),
      body,
    );

    DateTime? date;
    final dateMatch = RegExp(r'\bon\s+(\d{1,2})-(\d{1,2})-(\d{2,4})\b').firstMatch(body);
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
    final vpaMatch = RegExp(r'towards\s+VPA\s+(\S+)\s*\(([^)]+)\)', caseSensitive: false)
        .firstMatch(body);
    if (vpaMatch != null) {
      upiId = vpaMatch.group(1)?.trim();
      merchantName = vpaMatch.group(2)?.trim();
    }

    final refMatch =
        RegExp(r'UPI transaction reference no\.?:?\s*(\w+)', caseSensitive: false).firstMatch(body);
    final accountMatch =
        RegExp(r'account ending\s+(\w+)', caseSensitive: false).firstMatch(body);

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

final BankProfile unionBank = BankProfile(
  code: 'UBI',
  name: 'Union Bank',
  senderEmail: 'noreplyubi-txn@ubi.bank.in',
  badgeColor: const Color(0xFF7F1D1D),
  parse: (subject, body) {
    final amount = _parseAmount(
      RegExp(r'Amount\s*:\s*Rs\.?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
      body,
    );

    DateTime? date;
    final dateMatch = RegExp(
      r'Transaction Date and Time\s*:\s*(\d{1,2})-(\d{1,2})-(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})',
      caseSensitive: false,
    ).firstMatch(body);
    if (dateMatch != null) {
      final parts = dateMatch.groups([1, 2, 3, 4, 5, 6]).map((s) => int.tryParse(s ?? '')).toList();
      if (parts.every((p) => p != null)) {
        date = DateTime(parts[2]!, parts[1]!, parts[0]!, parts[3]!, parts[4]!, parts[5]!);
      }
    }

    String? line(String label) {
      final m = RegExp('$label\\s*:\\s*([^\n]+)', caseSensitive: false).firstMatch(body);
      return m?.group(1)?.trim();
    }

    return ParsedTransactionFields(
      amount: amount,
      date: date,
      merchantName: line('Payee Name'),
      upiId: null,
      referenceNo: line('Transaction ID/RRN'),
      transactionType: line('Channel'),
      status: line('Transaction Status'),
      accountMasked: line('Debit Account Number'),
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
