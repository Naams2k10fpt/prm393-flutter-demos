import 'package:flutter_test/flutter_test.dart';
import 'package:unit_testing/services/login_validator.dart';

void main() {
  late LoginValidator validator;
  setUp(() => validator = LoginValidator());

  group('Email Validation', () {
    test('accepts a correctly formatted email', () {
      // Arrange
      const email = 'user@example.com';

      // Act
      final result = validator.isValidEmail(email);

      // Assert
      expect(result, isTrue);
    });

    test('rejects missing @ and missing domain suffix', () {
      expect(validator.isValidEmail('invalid-email'), isFalse);
      expect(validator.isValidEmail('user@example'), isFalse);
    });

    test('rejects empty email and whitespace', () {
      expect(validator.isValidEmail(''), isFalse);
      expect(validator.isValidEmail('user name@example.com'), isFalse);
    });
  });

  group('Password Validation', () {
    test('rejects an empty password', () {
      expect(validator.isValidPassword(''), isFalse);
    });

    test('rejects seven characters', () {
      expect(validator.isValidPassword('1234567'), isFalse);
    });

    test('accepts exactly eight characters', () {
      expect(validator.isValidPassword('12345678'), isTrue);
    });

    test('counts a supplementary Unicode code point once', () {
      expect(validator.isValidPassword('123456😀'), isFalse);
      expect(validator.isValidPassword('1234567😀'), isTrue);
    });
  });
}
