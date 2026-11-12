import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_api.dart';

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const AuthDemo(),
  ),
);

class AuthDemo extends StatefulWidget {
  const AuthDemo({super.key});

  @override
  State<AuthDemo> createState() => _AuthDemoState();
}

class _AuthDemoState extends State<AuthDemo> {
  final httpClient = http.Client();
  late final api = AuthApi(apiUrl, httpClient, const FlutterSecureStorage());
  final form = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool signup = false;
  bool busy = true;
  bool restored = false;
  String? status;
  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    _run(_restore);
  }

  @override
  void dispose() {
    httpClient.close();
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await action();
    } on AuthException catch (error) {
      status = error.message;
    } catch (_) {
      status = 'Không thể xử lý phiên đăng nhập. Hãy thử lại.';
    } finally {
      if (!api.hasSession) profile = null;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    await api.restore();
    restored = true;
    if (api.hasSession) await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await api.profile();
    profile = result.user;
    status = result.refreshed
        ? 'Access token đã được làm mới.'
        : 'Đã tải hồ sơ từ API.';
  }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    await _run(() async {
      final address = email.text.trim();
      if (signup) {
        await api.register(address, password.text, fullName.text.trim());
        signup = false;
        status = 'Đăng ký thành công. Hãy đăng nhập.';
      } else {
        await api.login(address, password.text);
        if (mounted) password.clear();
        await _loadProfile();
      }
      if (mounted) {
        password.clear();
        confirmation.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('02 · Xác thực JWT')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (!restored && !busy)
            OutlinedButton(
              onPressed: () => _run(_restore),
              child: const Text('Thử đọc lại phiên'),
            ),
          if (restored && api.hasSession) ...[
            Text(
              'Hồ sơ được bảo vệ',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (profile != null) ...[
              Text('${profile!['fullName']}'),
              Text('${profile!['email']}'),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : () => _run(_loadProfile),
              child: const Text('Tải lại hồ sơ'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      await api.logout();
                      status = 'Đã đăng xuất.';
                    }),
              child: const Text('Đăng xuất'),
            ),
          ] else if (restored)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    signup ? 'Tạo tài khoản' : 'Đăng nhập',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (signup)
                    TextFormField(
                      enabled: !busy,
                      controller: fullName,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Nhập họ và tên' : null,
                    ),
                  TextFormField(
                    enabled: !busy,
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value!.trim())
                        ? null
                        : 'Nhập email hợp lệ',
                  ),
                  TextFormField(
                    enabled: !busy,
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (value) =>
                        value!.runes.length >= 8 ? null : 'Cần ít nhất 8 ký tự',
                  ),
                  if (signup)
                    TextFormField(
                      enabled: !busy,
                      controller: confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                      ),
                      validator: (value) =>
                          value == password.text ? null : 'Mật khẩu chưa khớp',
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(signup ? 'Đăng ký' : 'Đăng nhập'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            form.currentState!.clearError();
                            setState(() {
                              signup = !signup;
                              status = null;
                            });
                          },
                    child: Text(
                      signup ? 'Quay lại đăng nhập' : 'Tạo tài khoản',
                    ),
                  ),
                ],
              ),
            ),
          if (status != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(status!)),
          ],
        ],
      ),
    ),
  );
}
