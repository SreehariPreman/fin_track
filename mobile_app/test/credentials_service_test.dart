import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/credentials_service.dart';

void main() {
  group('CredentialsService.displayNameFromEmail', () {
    test('title-cases the local part and splits it on separators', () {
      expect(CredentialsService.displayNameFromEmail('priya.s@gmail.com'), 'Priya S');
      expect(CredentialsService.displayNameFromEmail('anil_kumar@gmail.com'), 'Anil Kumar');
      expect(CredentialsService.displayNameFromEmail('rahul@gmail.com'), 'Rahul');
    });

    test('drops digits used as disambiguators', () {
      expect(CredentialsService.displayNameFromEmail('meera99@gmail.com'), 'Meera');
      expect(CredentialsService.displayNameFromEmail('dev.k2@gmail.com'), 'Dev K');
    });

    test('returns null when there is no name to show', () {
      expect(CredentialsService.displayNameFromEmail(null), isNull);
      expect(CredentialsService.displayNameFromEmail(''), isNull);
      expect(CredentialsService.displayNameFromEmail('12345@gmail.com'), isNull);
    });
  });
}
