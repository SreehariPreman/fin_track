import 'package:flutter/foundation.dart';
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

  /// Per-response ceiling. A single IMAP response has no business taking
  /// this long, and without a bound a stalled connection leaves the UI
  /// spinning forever with nothing to report — the fetch never fails, it
  /// just never finishes. Deliberately per-operation rather than one
  /// timeout around the whole fetch, so a large but healthy catch-up
  /// isn't killed for being slow.
  static const Duration _responseTimeout = Duration(seconds: 30);
  static const Duration _writeTimeout = Duration(seconds: 20);

  /// Collects recognised bank-alert emails, newest first.
  ///
  /// [since] puts a hard floor on how far back to look. When it's set the
  /// server does the filtering — an IMAP SEARCH on both the date and the
  /// known bank senders — instead of this walking the mailbox and opening
  /// every message to find out. On an account with years of mail that is
  /// the difference between one cheap query and downloading the inbox.
  ///
  /// [maxCount] caps how many are returned; null means "everything in
  /// range", which is what the one-off catch-up from the tracking start
  /// date uses.
  ///
  /// [onProgress] reports what the fetch is currently doing. The catch-up
  /// can legitimately run for a while, and a bare spinner gives no way to
  /// tell a slow fetch from a stuck one.
  Future<List<UpiTransaction>> fetchLastUpiTransactions({
    required String email,
    required String appPasscode,
    int? maxCount = 10,
    DateTime? since,
    void Function(String message)? onProgress,
  }) async {
    final client = ImapClient(
      isLogEnabled: false,
      defaultResponseTimeout: _responseTimeout,
      defaultWriteTimeout: _writeTimeout,
    );
    final results = <UpiTransaction>[];

    try {
      onProgress?.call('Connecting to Gmail…');
      await client.connectToServer(host, port, isSecure: true);
      await client.login(email, appPasscode);
      final mailbox = await client.selectInbox();

      final totalMessages = mailbox.messagesExists;
      if (totalMessages == 0) return results;

      if (since != null) {
        // `await` is load-bearing. Returning the future bare lets control
        // leave the try block immediately, which runs the finally — and
        // the finally logs out and closes the socket. The fetch was then
        // issued on a dead connection and simply never answered, so every
        // date-filtered fetch failed on the response timeout exactly 30s
        // later, looking for all the world like a slow mailbox.
        return await _fetchSince(client, since, maxCount, onProgress);
      }

      onProgress?.call('Reading recent mail…');

      const batchSize = 30;
      var end = totalMessages;

      while (end >= 1 && (maxCount == null || results.length < maxCount)) {
        final start = (end - batchSize + 1).clamp(1, end);
        final sequence = MessageSequence.fromRange(start, end);
        final fetchResult = await client.fetchMessages(sequence, 'BODY.PEEK[]');

        // Newest first within the batch.
        final messages = fetchResult.messages.reversed;
        for (final msg in messages) {
          if (maxCount != null && results.length >= maxCount) break;

          final transaction = _toTransaction(msg);
          if (transaction != null) results.add(transaction);
        }

        end = start - 1;
      }

      return results;
    } finally {
      // Always close the socket, even when the polite goodbye fails.
      //
      // logout() goes through the same command queue as everything else,
      // so a client already wedged by a timeout can't complete it either
      // — it just waits out another response timeout and leaves the
      // connection open. Gmail caps simultaneous IMAP connections per
      // account, so each leak makes the next fetch likelier to be
      // throttled, which is how one slow fetch turns into a run of
      // "sometimes it times out".
      try {
        await client.logout().timeout(const Duration(seconds: 5));
      } catch (_) {
        // ignore: the disconnect below is what actually matters
      }
      try {
        await client.disconnect();
      } catch (_) {
        // nothing left to do; the socket is going away regardless
      }
    }
  }


  /// Parses one fetched message into a transaction, or null if it isn't
  /// one. Shared by both fetch paths so they can't drift apart on what
  /// counts as a transaction.
  UpiTransaction? _toTransaction(MimeMessage msg) {
    final fromEmail = (msg.from?.isNotEmpty ?? false) ? msg.from!.first.email : '';
    final bank = bankProfileForSender(fromEmail);
    if (bank == null) return null;

    final subject = msg.decodeSubject() ?? '';
    final plainPart = msg.decodeTextPlainPart();
    final body = (plainPart != null && plainPart.trim().isNotEmpty)
        ? plainPart.trim()
        : _stripHtml(msg.decodeTextHtmlPart() ?? '').trim();

    final parsed = bank.parse(subject, body);
    // A recognised bank sender also sends non-transaction mail (e.g.
    // HDFC's "Successfully Set-up 4 Digit...", "View: Account
    // update..." notifications) — a genuine UPI debit/credit alert
    // always has a parseable amount, so no amount means "not
    // actually a transaction" and it's skipped rather than saved as
    // one with a blank amount.
    if (parsed.amount == null) return null;
    // Spending only. Anything that isn't positively identified as a
    // debit — a credit, or an alert this bank's parser couldn't read
    // confidently — is dropped here rather than stored. This is the
    // single place email becomes a transaction, so rejecting here is
    // sufficient: nothing downstream has to re-check direction.
    if (parsed.direction != TransactionDirection.debit) return null;
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

    return UpiTransaction(
      emailId: (msg.sequenceId ?? 0).toString(),
      subject: subject.length > 120 ? subject.substring(0, 120) : subject,
      amount: parsed.amount,
      date: date,
      // Never fall back to dumping the raw body here — if merchant
      // extraction failed, the subject line is still a much safer
      // "name" to show than an arbitrary chunk of the email.
      snippet: merchant ?? (subject.isNotEmpty ? subject : '${bank.name} transaction'),
      body: body,
      bankCode: bank.code,
      bankName: bank.name,
      merchantName: merchant,
      upiId: parsed.upiId,
      referenceNo: parsed.referenceNo,
      transactionType: parsed.transactionType,
      status: parsed.status,
    );
  }

  /// Server-side fetch: ask IMAP for exactly the messages that are from a
  /// known bank sender and no older than [since], then download only
  /// those.
  Future<List<UpiTransaction>> _fetchSince(
    ImapClient client,
    DateTime since,
    int? maxCount,
    void Function(String message)? onProgress,
  ) async {
    onProgress?.call('Searching for bank mail…');
    final search = await client.searchMessages(
      searchCriteria: _sinceFromBanksCriteria(since),
      responseTimeout: _responseTimeout,
    );
    var ids = search.matchingSequence?.toList() ?? const <int>[];
    if (ids.isEmpty) {
      onProgress?.call('No bank mail found since that date');
      return [];
    }

    // SEARCH returns ascending sequence ids; newest are at the end.
    ids.sort();
    if (maxCount != null && ids.length > maxCount) {
      ids = ids.sublist(ids.length - maxCount);
    }

    final results = <UpiTransaction>[];
    final total = ids.length;
    onProgress?.call('Found $total message${total == 1 ? '' : 's'}…');

    // Chunked for progress granularity and to bound memory on a wide date
    // range, not for speed — measured against a real mailbox, one fetch of
    // 16 messages took 0.9s versus 1.6s in chunks of five, since each
    // chunk is another round trip. Twenty keeps a typical catch-up to a
    // single request while still breaking a few-hundred-message backfill
    // into visible steps.
    const chunkSize = 20;
    var read = 0;
    for (var i = ids.length; i > 0; i -= chunkSize) {
      final chunk = ids.sublist((i - chunkSize).clamp(0, ids.length), i);
      if (chunk.isEmpty) continue;
      final sequence = MessageSequence.fromIds(chunk);
      final fetched = await client.fetchMessages(
        sequence,
        'BODY.PEEK[]',
        responseTimeout: _responseTimeout,
      );
      for (final msg in fetched.messages.reversed) {
        final transaction = _toTransaction(msg);
        if (transaction != null) results.add(transaction);
      }
      // Reported after the work, not before it, so the number reflects
      // what has actually been downloaded.
      read += chunk.length;
      onProgress?.call('Read $read of $total…');
    }
    return results;
  }

  /// `SINCE <date> (OR FROM a FROM b ...)`.
  ///
  /// SINCE compares the server's internal date at day granularity and is
  /// inclusive, so the start date the user picked is itself covered. The
  /// sender clause is folded because IMAP's OR is strictly binary.
  static String _sinceFromBanksCriteria(DateTime since) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final date = '${since.day.toString().padLeft(2, '0')}'
        '-${months[since.month - 1]}-${since.year}';

    final senders =
        bankProfiles.map((b) => 'FROM "${b.senderEmail}"').toList();
    var clause = senders.first;
    for (final sender in senders.skip(1)) {
      clause = 'OR $clause $sender';
    }
    return 'SINCE $date ($clause)';
  }

  /// Strips HTML to plain text while preserving line breaks — collapsing
  /// everything (including block-level tags) to spaces turns a structured
  /// "Label : value" email into one giant line, which breaks per-field
  /// parsing (a "until end of line" regex then captures the rest of the
  /// whole email instead of just that field).
  @visibleForTesting
  static String stripHtmlForTesting(String html) => _stripHtml(html);

  /// IMAP search syntax is unforgiving and can't be exercised without a
  /// live server, so the criteria string is pinned by tests.
  @visibleForTesting
  static String searchCriteriaForTesting(DateTime since) =>
      _sinceFromBanksCriteria(since);

  static String _stripHtml(String html) {
    var text = html
        // <style>/<script> blocks must be removed *with their contents* —
        // otherwise raw CSS/JS text ends up looking like part of the mail.
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        // Any <br ...> variant (attributes, self-closed or not).
        .replaceAll(RegExp(r'<br[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|tr|li|h[1-6])\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'&(#39|apos);'), "'")
        .replaceAll(RegExp(r'&#60;'), '<')
        .replaceAll(RegExp(r'&#62;'), '>')
        .replaceAll('&quot;', '"');
    // Collapse repeated spaces/tabs (but not newlines), and repeated blank lines.
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return text.trim();
  }
}
