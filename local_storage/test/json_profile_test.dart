import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/json_profile.dart';

void main() {
  test(
    'JSON survives a new store instance, supports overwrite and deletion',
    () async {
      final dir = await Directory.systemTemp.createTemp('prm393-profile-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/profile.json');
      final profile = JsonProfile(file);

      expect(await profile.load(), isNull);
      await profile.save('Nguyễn An', 21);
      expect(await JsonProfile(file).load(), {'name': 'Nguyễn An', 'age': 21});
      await profile.save('Trần Bình', 22);
      expect(await profile.load(), {'name': 'Trần Bình', 'age': 22});
      await profile.delete();
      expect(await profile.load(), isNull);
    },
  );
}
