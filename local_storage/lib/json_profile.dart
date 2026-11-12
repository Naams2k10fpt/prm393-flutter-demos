import 'dart:convert';
import 'dart:io';

class JsonProfile {
  JsonProfile(this.file);

  final File file;

  Future<void> save(String name, int age) async {
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({'name': name, 'age': age}),
      flush: true,
    );
    await pending.rename(file.path);
  }

  Future<Map<String, dynamic>?> load() async {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
  }
}
