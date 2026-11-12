import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthApi {
  AuthApi(this.baseUrl, this.client, this.storage);

  static const _sessionKey = 'prm393_jwt_session';
  final String baseUrl;
  final http.Client client;
  final FlutterSecureStorage storage;
  ({String access, String refresh})? _session;

  bool get hasSession => _session != null;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, String>? data,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response =
          await (data == null
                  ? client.get(uri, headers: {'Authorization': 'Bearer $token'})
                  : client.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(data),
                    ))
              .timeout(const Duration(seconds: 8));

      if (response.statusCode == 204) return {};
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) return body;

      final message = body['message'] as String? ?? 'Yêu cầu thất bại.';
      if (response.statusCode == 401) throw _Unauthorized(message);
      throw AuthException(message);
    } on TimeoutException {
      throw const AuthException('API phản hồi quá chậm. Hãy thử lại.');
    } on http.ClientException {
      throw const AuthException(
        'Không kết nối được. Hãy kiểm tra backend và URL.',
      );
    } on FormatException {
      throw const AuthException('Backend trả về dữ liệu không đúng định dạng.');
    } on TypeError {
      throw const AuthException('Backend trả về dữ liệu không đúng định dạng.');
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    await _request(
      '/api/auth/register',
      data: {'email': email, 'password': password, 'fullName': fullName},
    );
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    final access = body['accessToken'];
    final refresh = body['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const AuthException('Backend chưa trả về đủ token.');
    }
    await storage.write(
      key: _sessionKey,
      value: jsonEncode({'accessToken': access, 'refreshToken': refresh}),
    );
    _session = (access: access, refresh: refresh);
  }

  Future<void> login(String email, String password) async {
    final body = await _request(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    await _saveSession(body);
  }

  Future<void> restore() async {
    final saved = await storage.read(key: _sessionKey);
    if (saved == null) return;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      _session = (
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
    } on FormatException {
      await _clearSession();
    } on TypeError {
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    await storage.delete(key: _sessionKey);
    _session = null;
  }

  Future<({Map<String, dynamic> user, bool refreshed})> profile() async {
    final session = _session;
    if (session == null) throw const AuthException('Hãy đăng nhập.');
    try {
      final user = await _request('/api/users/me', token: session.access);
      return (user: user, refreshed: false);
    } on _Unauthorized {
      try {
        final renewed = await _request(
          '/api/auth/refresh',
          data: {'refreshToken': session.refresh},
        );
        await _saveSession(renewed);
        final user = await _request('/api/users/me', token: _session!.access);
        return (user: user, refreshed: true);
      } on _Unauthorized {
        await _clearSession();
        throw const AuthException('Phiên đã hết hạn. Hãy đăng nhập lại.');
      }
    }
  }

  Future<void> logout() async {
    final session = _session;
    try {
      if (session != null) {
        await _request(
          '/api/auth/logout',
          data: {'refreshToken': session.refresh},
        );
      }
    } on AuthException {
      throw const AuthException(
        'Đã đăng xuất trên thiết bị. Backend chưa xác nhận thu hồi phiên.',
      );
    } finally {
      await _clearSession();
    }
  }
}

class _Unauthorized extends AuthException {
  const _Unauthorized(super.message);
}
