import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads and opens an APK for system install (Android only, PLAN §11.9.1).
class ApkUpdateInstaller {
  ApkUpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> downloadApk(
    String url, {
    String? outputPath,
    void Function(int received, int? totalBytes)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final response = await _client.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final file = outputPath != null
        ? File(outputPath)
        : File(
            p.join(
              (await getTemporaryDirectory()).path,
              'meshpad-update.apk',
            ),
          );
    if (await file.exists()) await file.delete();

    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();
    MeshPadLog.metric('apk_update_bytes', '$received');
    return file.path;
  }

  Future<OpenResult> promptInstall(String apkPath) {
    return OpenFile.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
  }

  void close() => _client.close();
}

bool get supportsInAppApkUpdate => Platform.isAndroid;
