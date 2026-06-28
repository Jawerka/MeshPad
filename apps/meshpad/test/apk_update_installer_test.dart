import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshpad/core/services/apk_update_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('downloadApk writes response bytes to a file', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(List<int>.filled(128, 7), 200);
    });

    final temp = await Directory.systemTemp.createTemp('meshpad_apk_');
    final out = File('${temp.path}/update.apk').path;
    final installer = ApkUpdateInstaller(client: client);
    final path = await installer.downloadApk(
      'https://example.com/app.apk',
      outputPath: out,
    );
    installer.close();

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 128);
    await file.delete();
    await temp.delete(recursive: true);
  });
}
