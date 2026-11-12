import 'package:flutter/material.dart';

import 'services/login_validator.dart';

void main() => runApp(const ValidatorDemo());

class ValidatorDemo extends StatelessWidget {
  const ValidatorDemo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
    home: const ValidatorPage(),
  );
}

class ValidatorPage extends StatefulWidget {
  const ValidatorPage({super.key});

  @override
  State<ValidatorPage> createState() => _ValidatorPageState();
}

class _ValidatorPageState extends State<ValidatorPage> {
  final form = GlobalKey<FormState>();
  final validator = LoginValidator();
  bool? valid;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('03 · Unit test cho form đăng nhập')),
    body: SafeArea(
      child: Form(
        key: form,
        onChanged: () {
          if (valid != null) setState(() => valid = null);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Email đúng định dạng và mật khẩu có ít nhất 8 ký tự.'),
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => validator.isValidEmail(value ?? '')
                  ? null
                  : 'Email không hợp lệ',
            ),
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              validator: (value) => validator.isValidPassword(value ?? '')
                  ? null
                  : 'Cần ít nhất 8 ký tự',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  setState(() => valid = form.currentState!.validate()),
              child: const Text('Kiểm tra'),
            ),
            if (valid != null)
              Text(
                valid!
                    ? 'Dữ liệu hợp lệ.'
                    : 'Kiểm tra các trường được đánh dấu.',
              ),
          ],
        ),
      ),
    ),
  );
}
