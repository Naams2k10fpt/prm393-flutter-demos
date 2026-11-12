import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jwt_auth/auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores tokens and retries the profile once after rotation', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final calls = <String>[];
    final client = MockClient((request) async {
      final token = request.headers['authorization'];
      final path = request.url.path;
      calls.add('$path ${token ?? ''}'.trim());
      return switch (path) {
        '/api/auth/login' => http.Response(
          '{"accessToken":"old","refreshToken":"first"}',
          200,
        ),
        '/api/auth/refresh' => http.Response(
          '{"accessToken":"new","refreshToken":"second"}',
          200,
        ),
        '/api/users/me' when token == 'Bearer old' => http.Response(
          '{"message":"Expired"}',
          401,
        ),
        '/api/users/me' when token == 'Bearer new' => http.Response(
          '{"fullName":"Demo"}',
          200,
        ),
        '/api/auth/logout' => http.Response('', 204),
        _ => throw StateError('Unexpected request: $request'),
      };
    });
    final api = AuthApi('http://localhost', client, storage);
    await api.login('demo@example.com', 'example-password');
    final restored = AuthApi('http://localhost', client, storage);
    await restored.restore();
    final result = await restored.profile();
    expect(result.refreshed, isTrue);
    expect(result.user['fullName'], 'Demo');
    final saved = await storage.readAll();
    expect(jsonDecode(saved.values.single)['refreshToken'], 'second');

    await restored.logout();
    expect(restored.hasSession, isFalse);
    expect(await storage.readAll(), isEmpty);
    expect(calls, [
      '/api/auth/login',
      '/api/users/me Bearer old',
      '/api/auth/refresh',
      '/api/users/me Bearer new',
      '/api/auth/logout',
    ]);
  });
}
