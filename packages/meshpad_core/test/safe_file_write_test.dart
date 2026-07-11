import 'dart:io';

import 'package:meshpad_core/src/storage/safe_file_write.dart';
import 'package:test/test.dart';

void main() {
  test('writeTextFileResilient creates and updates file', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_safe_write_');
    final file = File('${dir.path}/sample.txt');

    await writeTextFileResilient(file, 'first');
    expect(await file.readAsString(), 'first');

    await writeTextFileResilient(file, 'second');
    expect(await file.readAsString(), 'second');
  });

  test('DirectoryCreationLock serializes concurrent work', () async {
    var active = 0;
    var maxActive = 0;

    await Future.wait(
      List.generate(
        6,
        (_) => DirectoryCreationLock.run('key', () async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          active--;
        }),
      ),
    );

    expect(maxActive, 1);
  });
}
