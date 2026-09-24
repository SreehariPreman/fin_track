import 'package:flutter_test/flutter_test.dart';
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
}
