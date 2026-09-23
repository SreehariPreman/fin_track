import 'package:enough_mail/enough_mail.dart';

import '../models/transaction.dart';
import 'parser_service.dart';

/// Connects directly to Gmail IMAP from the device (no backend) and pulls
/// the most recent UPI-related emails. Mirrors fetch_last_upi_transactions()
/// from the desktop app's email_service.py.
class ImapService {
  static const String host = 'imap.gmail.com';
  static const int port = 993;

  /// Scans the inbox newest-first in batches until [maxCount] UPI-related
  /// emails are found (or the inbox is exhausted).
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

          final subject = msg.decodeSubject() ?? '';
          final body = (msg.decodeTextPlainPart() ??
                  _stripHtml(msg.decodeTextHtmlPart() ?? ''))
              .trim();

          if (!ParserService.isUpiRelated(subject, body)) continue;

          final textForParse = '$subject $body';
          final amount = ParserService.parseAmount(textForParse);
          final date = ParserService.parseDateFromBody(body) ?? msg.decodeDate();
          final snippet = body.isNotEmpty
              ? ParserService.extractSnippet(body)
              : (subject.length > 200 ? subject.substring(0, 200) : subject);

          results.add(UpiTransaction(
            emailId: (msg.sequenceId ?? 0).toString(),
            subject: subject.length > 120 ? subject.substring(0, 120) : subject,
            amount: amount,
            date: date,
            snippet: snippet,
            body: body,
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

  static String _stripHtml(String html) {
    final noTags = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
