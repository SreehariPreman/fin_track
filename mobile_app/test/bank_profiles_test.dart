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
  });

  group('HDFC Bank — credit notification (real-world sample that regressed)', () {
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
  });
}
