import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Saves a local path or remote URL to a user-chosen location.
Future<bool> saveAttachmentFile({
  required String source,
  required String fileName,
}) async {
  if (kIsWeb || source.isEmpty) return false;

  final suggestedName = p.basename(fileName.isNotEmpty ? fileName : source);
  final bytes = await _loadBytes(source);
  if (bytes == null) return false;

  // [bytes] is required on Android/iOS; desktop also accepts it.
  final savedPath = await FilePicker.platform.saveFile(
    fileName: suggestedName,
    bytes: bytes,
  );
  return savedPath != null;
}

Future<Uint8List?> _loadBytes(String source) async {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    final response = await http.get(Uri.parse(source));
    if (response.statusCode >= 400) return null;
    return response.bodyBytes;
  }

  final file = File(source);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
