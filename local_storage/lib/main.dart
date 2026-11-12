import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'json_profile.dart';

void main() => runApp(const StorageDemo());

class StorageDemo extends StatefulWidget {
  const StorageDemo({super.key});

  @override
  State<StorageDemo> createState() => _StorageDemoState();
}

class _StorageDemoState extends State<StorageDemo> {
  final prefs = SharedPreferencesAsync();
  final username = TextEditingController();
  final name = TextEditingController();
  final age = TextEditingController();
  final task = TextEditingController();

  JsonProfile? profile;
  Database? db;
  bool dark = false;
  bool busy = true;
  int launches = 0;
  String savedUsername = 'Khách';
  String? status;
  List<Map<String, Object?>> tasks = [];

  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  @override
  void dispose() {
    username.dispose();
    name.dispose();
    age.dispose();
    task.dispose();
    db?.close();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, [String? message]) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await action();
      status ??= message;
    } catch (error) {
      status = 'Lỗi lưu trữ: $error';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = JsonProfile(File('${dir.path}/prm393_profile.json'));
    db ??= await openDatabase(
      '${await getDatabasesPath()}/prm393_tasks.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)',
      ),
    );
    await _readTasks();
    dark = await prefs.getBool('darkMode') ?? false;
    username.text = await prefs.getString('username') ?? '';
    savedUsername = username.text.isEmpty ? 'Khách' : username.text;
    launches = (await prefs.getInt('launchCount') ?? 0) + 1;
    await prefs.setInt('launchCount', launches);
    profile = store;
    try {
      await _readProfile();
    } on FormatException {
      status = 'File JSON lỗi. Nhập hồ sơ mới để ghi đè hoặc chọn Xóa file.';
    } on TypeError {
      status = 'File JSON sai cấu trúc. Bạn có thể ghi đè hoặc xóa file.';
    }
  }

  Future<void> _readProfile() async {
    final data = await profile!.load();
    name.text = data?['name'] as String? ?? '';
    age.text = (data?['age'] as int?)?.toString() ?? '';
  }

  Future<void> _readTasks() async {
    tasks = await db!.query('tasks', orderBy: 'done, id DESC');
  }

  void _saveProfile() {
    final years = int.tryParse(age.text.trim());
    if (name.text.trim().isEmpty || years == null || years < 0 || years > 150) {
      setState(() => status = 'Nhập họ tên và tuổi từ 0 đến 150.');
      return;
    }
    _run(
      () => profile!.save(name.text.trim(), years),
      'Đã ghi hồ sơ vào JSON.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !busy && profile != null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('01 · Lưu trữ cục bộ')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(status!, semanticsLabel: status),
                ),
              if (!busy && profile == null)
                OutlinedButton(
                  onPressed: () => _run(_load),
                  child: const Text('Thử lại'),
                ),
              const Text(
                'SharedPreferencesAsync',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text('Tên đã lưu: $savedUsername · Số lần mở: $launches'),
              TextField(
                controller: username,
                enabled: ready,
                decoration: const InputDecoration(labelText: 'Tên người dùng'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chế độ tối'),
                value: dark,
                onChanged: ready
                    ? (value) => _run(() async {
                        await prefs.setBool('darkMode', value);
                        dark = value;
                      })
                    : null,
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: ready
                        ? () => _run(() async {
                            final value = username.text.trim();
                            if (value.isEmpty) {
                              await prefs.remove('username');
                            } else {
                              await prefs.setString('username', value);
                            }
                            savedUsername = value.isEmpty ? 'Khách' : value;
                          }, 'Đã lưu tên.')
                        : null,
                    child: const Text('Lưu tên'),
                  ),
                  OutlinedButton(
                    onPressed: ready
                        ? () => _run(() async {
                            await prefs.clear(
                              allowList: {
                                'username',
                                'darkMode',
                                'launchCount',
                              },
                            );
                            username.clear();
                            savedUsername = 'Khách';
                            dark = false;
                            launches = 0;
                          }, 'Đã xóa tùy chọn.')
                        : null,
                    child: const Text('Đặt lại tùy chọn'),
                  ),
                ],
              ),
              const Divider(height: 36),
              const Text(
                'Dart IO + JSON',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: name,
                enabled: ready,
                decoration: const InputDecoration(labelText: 'Họ tên hồ sơ'),
              ),
              TextField(
                controller: age,
                enabled: ready,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tuổi'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: ready ? _saveProfile : null,
                    child: const Text('Ghi JSON'),
                  ),
                  OutlinedButton(
                    onPressed: ready
                        ? () => _run(_readProfile, 'Đã đọc lại hồ sơ.')
                        : null,
                    child: const Text('Đọc JSON'),
                  ),
                  OutlinedButton(
                    onPressed: ready
                        ? () => _run(() async {
                            await profile!.delete();
                            await _readProfile();
                          }, 'Đã xóa file.')
                        : null,
                    child: const Text('Xóa file'),
                  ),
                ],
              ),
              const Divider(height: 36),
              const Text(
                'SQLite',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: task,
                enabled: ready,
                decoration: const InputDecoration(labelText: 'Công việc mới'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: ready
                      ? () {
                          final title = task.text.trim();
                          if (title.isEmpty) {
                            setState(() => status = 'Nhập nội dung công việc.');
                            return;
                          }
                          _run(() async {
                            await db!.insert('tasks', {'title': title});
                            task.clear();
                            await _readTasks();
                          });
                        }
                      : null,
                  child: const Text('Thêm việc'),
                ),
              ),
              if (tasks.isEmpty) const Text('Chưa có công việc.'),
              for (final row in tasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    semanticLabel: 'Đã hoàn thành',
                    value: row['done'] == 1,
                    onChanged: ready
                        ? (value) => _run(() async {
                            await db!.update(
                              'tasks',
                              {'done': value == true ? 1 : 0},
                              where: 'id = ?',
                              whereArgs: [row['id']],
                            );
                            await _readTasks();
                          })
                        : null,
                  ),
                  title: Text(row['title'] as String),
                  trailing: IconButton(
                    tooltip: 'Xóa công việc',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: ready
                        ? () => _run(() async {
                            await db!.delete(
                              'tasks',
                              where: 'id = ?',
                              whereArgs: [row['id']],
                            );
                            await _readTasks();
                          })
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
