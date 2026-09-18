import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/utils/document_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegalDocumentValidators', () {
    test('platný NIF', () {
      expect(LegalDocumentValidators.isValidNif('00000000T'), isTrue);
    });

    test('neplatné kontrolní písmeno NIF', () {
      expect(LegalDocumentValidators.isValidNif('00000000A'), isFalse);
    });

    test('NIE X', () {
      expect(LegalDocumentValidators.isValidNie('X0000000T'), isTrue);
    });

    test('pasport', () {
      expect(LegalDocumentValidators.isValidPassport('AB1234567'), isTrue);
      expect(LegalDocumentValidators.isValidPassport('ab'), isFalse);
    });

    test('druhé příjmení u NIF', () {
      expect(LegalDocumentValidators.requiresSecondLastName('NIF'), isTrue);
      expect(LegalDocumentValidators.requiresSecondLastName('PAS'), isFalse);
    });
  });

  group('reservationSourceRequiresRh', () {
    test('OTA neposílá RH', () {
      expect(reservationSourceRequiresRh('Booking'), isFalse);
      expect(reservationSourceRequiresRh('Airbnb'), isFalse);
    });

    test('přímé rezervace RH ano', () {
      expect(reservationSourceRequiresRh('Direct'), isTrue);
      expect(reservationSourceRequiresRh('Other'), isTrue);
      expect(reservationSourceRequiresRh(null), isTrue);
    });
  });
}
