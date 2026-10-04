import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/bank_profiles.dart';
import 'package:mobile_app/services/imap_service.dart';

void main() {
  group('ImapService.stripHtmlForTesting', () {
    test('removes <style> blocks including their contents', () {
      const html = '''
        <html><head>
        <style>
          @media screen and (min-device-width: 320px) {
            table { width: 100%; }
          }
        </style>
        </head>
        <body>
          <p>Rs.1.00 has been successfully credited.</p>
        </body></html>
      ''';

      final text = ImapService.stripHtmlForTesting(html);

      expect(text, isNot(contains('@media')));
      expect(text, isNot(contains('table {')));
      expect(text, contains('Rs.1.00 has been successfully credited.'));
    });

    test('removes <script> blocks including their contents', () {
      const html = '<script>var x = 1; console.log(x);</script><p>Hello</p>';
      final text = ImapService.stripHtmlForTesting(html);
      expect(text, isNot(contains('console.log')));
      expect(text, contains('Hello'));
    });

    test('turns block-level tags into line breaks so fields stay on separate lines', () {
      const html = '<p>1. Payee Name : Best Bak</p><p>2. Amount : Rs. 145.00</p>';
      final text = ImapService.stripHtmlForTesting(html);
      expect(text.split('\n').where((l) => l.trim().isNotEmpty).length, 2);
    });

    test('turns <br> with attributes into a line break too', () {
      const html = 'Line one<br clear="all">Line two';
      final text = ImapService.stripHtmlForTesting(html);
      expect(text, contains('Line one\nLine two'));
    });
  });

  group('ImapService — SINCE search criteria', () {
    test('formats the date the way IMAP requires, zero-padded', () {
      final criteria = ImapService.searchCriteriaForTesting(DateTime(2026, 10, 1));
      expect(criteria, startsWith('SINCE 01-Oct-2026 '));
    });

    test('restricts the search to the known bank senders', () {
      final criteria = ImapService.searchCriteriaForTesting(DateTime(2026, 10, 1));
      for (final bank in bankProfiles) {
        expect(criteria, contains('FROM "${bank.senderEmail}"'));
      }
    });

    test('folds senders into binary ORs and parenthesises the clause', () {
      final criteria = ImapService.searchCriteriaForTesting(DateTime(2026, 1, 5));
      expect('OR '.allMatches(criteria).length, bankProfiles.length - 1);
      // Without the parentheses SINCE would bind to only the first branch
      // of the OR, quietly returning unfiltered mail for every other bank.
      expect(criteria, contains('(OR '));
      expect(criteria, endsWith(')'));
    });
  });
}
