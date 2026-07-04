import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:meshpad_core/meshpad_core.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/feed/attachment_paths.dart';
import 'save_attachment_file.dart';

Future<void> openExternalUrl(String href) async {
  final uri = _normalizeExternalUri(href);
  if (uri == null) return;

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (launched) return;

  if (!kIsWeb && Platform.isAndroid) {
    final fallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (fallback) return;
  }

  throw SyncTransportException('Не удалось открыть ссылку: $href');
}

Uri? _normalizeExternalUri(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;

  var uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (!uri.hasScheme) {
    if (trimmed.startsWith('www.')) {
      uri = Uri.parse('https://$trimmed');
    } else if (trimmed.contains('.') && !trimmed.contains(' ')) {
      uri = Uri.parse('https://$trimmed');
    }
  }

  if (uri.scheme == 'http' ||
      uri.scheme == 'https' ||
      uri.scheme == 'mailto' ||
      uri.scheme == 'tel') {
    return uri;
  }
  return null;
}

Future<void> openMarkdownLink({
  required String href,
  required Note note,
  String? dataDir,
  Uri? Function(AttachmentMeta attachment)? attachmentUriBuilder,
}) async {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return;

  final external = _normalizeExternalUri(trimmed);
  if (external != null) {
    await openExternalUrl(trimmed);
    return;
  }

  if (trimmed.startsWith('file://')) {
    final path = Uri.parse(trimmed).toFilePath(windows: Platform.isWindows);
    await _openLocalPath(path);
    return;
  }

  final attachmentName = p.basename(trimmed);
  AttachmentMeta? matched;
  for (final attachment in note.attachments) {
    if (attachment.name == attachmentName ||
        attachment.name == trimmed ||
        trimmed.endsWith('/${attachment.name}')) {
      matched = attachment;
      break;
    }
  }
  if (matched != null) {
    await openNoteAttachment(
      note: note,
      attachment: matched,
      dataDir: dataDir,
      remoteUri: attachmentUriBuilder?.call(matched),
    );
    return;
  }

  if (p.isAbsolute(trimmed) && !kIsWeb) {
    await _openLocalPath(trimmed);
  }
}

Future<void> openNoteAttachment({
  required Note note,
  required AttachmentMeta attachment,
  String? dataDir,
  Uri? remoteUri,
}) async {
  if (!kIsWeb &&
      !isImageAttachment(attachment) &&
      !isVideoAttachment(attachment) &&
      !isAudioAttachment(attachment)) {
    final saved = await saveNoteAttachment(
      note: note,
      attachment: attachment,
      dataDir: dataDir,
      remoteUri: remoteUri,
    );
    if (!saved) {
      throw SyncTransportException(
        'Не удалось сохранить файл: ${attachment.name}',
      );
    }
    return;
  }

  final localPath =
      dataDir == null ? null : noteAttachmentPath(note, attachment, dataDir);
  if (localPath != null && await File(localPath).exists()) {
    await _openLocalPath(localPath);
    return;
  }

  if (remoteUri == null) return;

  if (remoteUri.scheme == 'http' || remoteUri.scheme == 'https') {
    if (kIsWeb) {
      await openExternalUrl(remoteUri.toString());
      return;
    }
    final cached = await _downloadToCache(remoteUri, attachment.name);
    if (cached != null) {
      await _openLocalPath(cached);
      return;
    }
    await openExternalUrl(remoteUri.toString());
  }
}

Future<bool> saveNoteAttachment({
  required Note note,
  required AttachmentMeta attachment,
  String? dataDir,
  Uri? remoteUri,
}) async {
  if (kIsWeb) return false;

  final localPath =
      dataDir == null ? null : noteAttachmentPath(note, attachment, dataDir);
  if (localPath != null && await File(localPath).exists()) {
    return saveAttachmentFile(source: localPath, fileName: attachment.name);
  }

  if (remoteUri != null &&
      (remoteUri.scheme == 'http' || remoteUri.scheme == 'https')) {
    return saveAttachmentFile(
      source: remoteUri.toString(),
      fileName: attachment.name,
    );
  }

  return false;
}

Future<void> _openLocalPath(String path) async {
  if (kIsWeb) return;
  final result = await OpenFile.open(path);
  if (result.type != ResultType.done) {
    throw SyncTransportException(
      'Не удалось открыть файл: ${result.message}',
    );
  }
}

Future<String?> _downloadToCache(Uri uri, String fileName) async {
  try {
    final response = await http.get(uri);
    if (response.statusCode >= 400) return null;
    final temp = await getTemporaryDirectory();
    final safeName = p.basename(fileName);
    final dest = File(p.join(temp.path, 'meshpad_open_$safeName'));
    await dest.writeAsBytes(response.bodyBytes);
    return dest.path;
  } catch (_) {
    return null;
  }
}

/// Wraps bare `http(s)://…` tokens so [MarkdownBody] renders them as links.
String linkifyBareUrls(String markdown) {
  final pattern = RegExp(
    r'(?<!\]\()(?<!\()(https?://[^\s<>()\[\]]+)(?<![.,;:!?)\]])',
  );
  return markdown.replaceAllMapped(
    pattern,
    (match) => '[${match.group(1)}](${match.group(1)})',
  );
}
