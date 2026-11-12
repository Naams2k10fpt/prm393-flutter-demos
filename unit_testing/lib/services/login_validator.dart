class LoginValidator {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool isValidEmail(String email) => _emailPattern.hasMatch(email);

  bool isValidPassword(String password) => password.runes.length >= 8;
}
