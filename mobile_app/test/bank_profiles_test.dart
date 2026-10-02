import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/bank_profiles.dart';

void main() {
  group('HDFC Bank — debit alert', () {
    final body =
        'Dear Customer, Greetings from HDFC Bank! Rs.345.00 is debited from your '
        'account ending 8159 towards VPA ZEPTOMARKETPLACEPRIVAT-12682647.payu@indus '
        '(ZEPTO MARKETPLACE PRIVATE LIMITED) on 19-09-26. UPI transaction reference '
        'no.: 626234560761. If you did not authorize this transaction, please report '
        'it immediately at: a. When in India (Toll free): 1800 258 6161';

    test('extracts amount, merchant, VPA, reference, date', () {
      final f = hdfcBank.parse('subject', body);
      expect(f.amount, 345.00);
      expect(f.merchantName, 'ZEPTO MARKETPLACE PRIVATE LIMITED');
      expect(f.upiId, 'ZEPTOMARKETPLACEPRIVAT-12682647.payu@indus');
      expect(f.referenceNo, '626234560761');
      expect(f.date, DateTime(2026, 9, 19));
      // Must not have swallowed the trailing safety notice.
      expect(f.merchantName!.length, lessThan(60));
    });

    test('is identified as a debit', () {
      expect(hdfcBank.parse('subject', body).direction, TransactionDirection.debit);
    });
  });

  group('HDFC Bank — credit notification (must never be counted as spend)', () {
    // Reconstructed from an actual fetched + HTML-stripped body, including
    // a leaked <style> block (the original bug) to make sure the fix holds.
    final body =
        '@media screen and (min-device-width: 320px) and (max-device-width: 768px) '
        '{ table { width: 100%; } } Dear Customer, Greetings from HDFC Bank! '
        "We're writing to inform you that Rs.1.00 has been successfully credited to "
        'your HDFC Bank account ending in 8159. Transaction Details: a. Date: 23-09-26 '
        'b. Sender: SREEHARI K NAIR (VPA: sreeharipreman853-1@okhdfcbank) c. UPI '
        'Reference No.: 130133987883 Need Help? India (Toll-Free): 1800 258 6161';

    test('extracts amount, sender, VPA, reference, date despite leaked CSS', () {
      final f = hdfcBank.parse('subject', body);
      expect(f.amount, 1.00);
      expect(f.merchantName, 'SREEHARI K NAIR');
      expect(f.upiId, 'sreeharipreman853-1@okhdfcbank');
      expect(f.referenceNo, '130133987883');
      expect(f.date, DateTime(2026, 9, 23));
    });

    // The app tracks spending only. This body previously matched the same
    // alternation as a debit and was stored as one, silently inflating
    // every total; ImapService now drops anything that isn't a debit.
    test('is identified as a credit, not a debit', () {
      expect(hdfcBank.parse('subject', body).direction, TransactionDirection.credit);
    });
  });

  group('HDFC Bank — non-transaction notification', () {
    // The same sender address also sends alerts that aren't UPI
    // transactions at all (PIN setup, account update notices, etc.) —
    // these must not parse an amount, since imap_service.dart uses a null
    // amount as the signal to skip saving something as a "transaction".
    final body =
        'Dear Customer, Your 4 Digit PIN for HDFC Bank Debit Card ending 8159 has '
        'been successfully set up. If you did not perform this action, please '
        'contact us immediately at 1800 258 6161.';

    test('does not extract an amount from a non-transaction alert', () {
      final f = hdfcBank.parse('Successfully Set-up 4 Digit PIN', body);
      expect(f.amount, isNull);
    });

    test('direction is unknown, so it would be rejected on direction too', () {
      final f = hdfcBank.parse('Successfully Set-up 4 Digit PIN', body);
      expect(f.direction, TransactionDirection.unknown);
    });
  });

  group('Union Bank — fund transfer alert', () {
    // Flattened on purpose (no newlines) to simulate an HTML body whose
    // line breaks didn't survive stripping — the scenario that caused the
    // "whole email in every field" bug.
    final body =
        'Dear SREEHARI K NAIR, Greetings! Your fund transfer request through UPI has '
        'been processed successfully. Transaction Details 1. Payee Name : Best Bak '
        '2. Amount : Rs. 145.00 3. Channel : UPI 4. Transaction ID/RRN : 626735168820 '
        '5. Transaction Status : Success 6. Transaction Date and Time : 24-09-2026 '
        '21:31:42 7. Debit Account Number : *9903 If you have not initiated this '
        'transaction, please report it immediately by way of: SMS UEBT to 8879365472';

    test('each field is bounded to its own value, not the rest of the email', () {
      final f = unionBank.parse('subject', body);
      expect(f.merchantName, 'Best Bak');
      expect(f.amount, 145.00);
      expect(f.transactionType, 'UPI');
      expect(f.referenceNo, '626735168820');
      expect(f.status, 'Success');
      expect(f.date, DateTime(2026, 9, 24, 21, 31, 42));
      expect(f.accountMasked, '*9903');

      // None of these should have run on and captured later fields.
      expect(f.merchantName, isNot(contains('Amount')));
      expect(f.transactionType, isNot(contains('Transaction ID')));
      expect(f.status, isNot(contains('Debit Account')));
    });

    test('is identified as a debit via its Debit Account Number row', () {
      expect(unionBank.parse('subject', body).direction, TransactionDirection.debit);
    });

    test('is identified as a debit via its subject line', () {
      expect(
        unionBank.parse('DEBIT TRANSACTION ALERT', body).direction,
        TransactionDirection.debit,
      );
    });
  });

  group('Union Bank — alert with no debit markers', () {
    // Same sender, same labelled-field shape, but nothing saying it is a
    // debit. It must fall through as unknown rather than being assumed to
    // be spending.
    final body =
        'Dear SREEHARI K NAIR, Greetings! Transaction Details 1. Payee Name : Someone '
        '2. Amount : Rs. 500.00 3. Channel : UPI 4. Transaction ID/RRN : 999888777666 '
        '5. Transaction Status : Success 6. Transaction Date and Time : 24-09-2026 '
        '21:31:42';

    test('is not treated as a debit', () {
      final f = unionBank.parse('TRANSACTION ALERT', body);
      expect(f.amount, 500.00);
      expect(f.direction, TransactionDirection.unknown);
    });
  });
}
