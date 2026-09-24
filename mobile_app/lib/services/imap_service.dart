import 'package:enough_mail/enough_mail.dart';

import '../models/transaction.dart';
import 'bank_profiles.dart';

/// Connects directly to Gmail IMAP from the device (no backend) and pulls
/// the most recent alert emails from known bank senders (see
/// bank_profiles.dart) — rather than a keyword heuristic, we match the
/// sender address precisely and use that bank's own parser.
class ImapService {
  static const String host = 'imap.gmail.com';
  static const int port = 993;

  /// Scans the inbox newest-first in batches until [maxCount] recognised
  /// bank-alert emails are found (or the inbox is exhausted).
  Future<List<UpiTransaction>> fetchLastUpiTransactions({
    required String email,
    required String appPasscode,
    int maxCount = 10,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    final results = <UpiTransaction>[];

    try {
      await client.connectToServer(host, port, isSecure: true);
      await client.login(email, appPasscode);
      final mailbox = await client.selectInbox();

      final totalMessages = mailbox.messagesExists;
      if (totalMessages == 0) return results;

      const batchSize = 30;
      var end = totalMessages;

      while (end >= 1 && results.length < maxCount) {
        final start = (end - batchSize + 1).clamp(1, end);
        final sequence = MessageSequence.fromRange(start, end);
        final fetchResult = await client.fetchMessages(sequence, 'BODY.PEEK[]');

        // Newest first within the batch.
        final messages = fetchResult.messages.reversed;
        for (final msg in messages) {
          if (results.length >= maxCount) break;

          final fromEmail = (msg.from?.isNotEmpty ?? false) ? msg.from!.first.email : '';
          final bank = bankProfileForSender(fromEmail);
          if (bank == null) continue;

          final subject = msg.decodeSubject() ?? '';
          final body = (msg.decodeTextPlainPart() ??
                  _stripHtml(msg.decodeTextHtmlPart() ?? ''))
              .trim();

          final parsed = bank.parse(subject, body);
          // Some banks' alert bodies (e.g. HDFC) only give a date, no time
          // of day — the parsed value then lands exactly at midnight, which
          // is indistinguishable from "no time info" and misleading in the
          // UI. Prefer the mail's own timestamp (which has a real time)
          // whenever the parsed date looks like a bare date.
          final looksTimeless = parsed.date != null &&
              parsed.date!.hour == 0 &&
              parsed.date!.minute == 0 &&
              parsed.date!.second == 0;
          final date = (parsed.date != null && !looksTimeless)
              ? parsed.date
              : (msg.decodeDate() ?? parsed.date);
          final merchant = parsed.merchantName;

          results.add(UpiTransaction(
            emailId: (msg.sequenceId ?? 0).toString(),
            subject: subject.length > 120 ? subject.substring(0, 120) : subject,
            amount: parsed.amount,
            date: date,
            snippet: merchant ?? (body.isNotEmpty ? body : subject).replaceAll('\n', ' ').trim(),
            body: body,
            bankCode: bank.code,
            bankName: bank.name,
            merchantName: merchant,
            upiId: parsed.upiId,
            referenceNo: parsed.referenceNo,
            transactionType: parsed.transactionType,
            status: parsed.status,
          ));
        }

        end = start - 1;
      }

      return results;
    } finally {
      try {
        await client.logout();
      } catch (_) {
        // ignore logout failures
      }
    }
  }

  /// Strips HTML to plain text while preserving line breaks — collapsing
  /// everything (including block-level tags) to spaces turns a structured
  /// "Label : value" email into one giant line, which breaks per-field
  /// parsing (a "until end of line" regex then captures the rest of the
  /// whole email instead of just that field).
  static String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|tr|li|h[1-6])\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'&(#39|apos);'), "'")
        .replaceAll('&quot;', '"');
    // Collapse repeated spaces/tabs (but not newlines), and repeated blank lines.
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return text.trim();
  }
}
