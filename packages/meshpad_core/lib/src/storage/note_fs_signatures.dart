import 'dart:io';

import 'package:path/path.dart' as p;

import 'meshpad_paths.dart';

/// File mtimes used to skip unchanged notes during reconcile (PLAN §11.5.1).
class NoteFsSignatures {
  const NoteFsSignatures({
    required this.metaModifiedAt,
    required this.markdownModifiedAt,
    this.attachmentsModifiedAt,
  });

  final DateTime metaModifiedAt;
  final DateTime markdownModifiedAt;
  final DateTime? attachmentsModifiedAt;

  /// Truncates to UTC ms so Drift round-trips match [File.stat] reads.
  static DateTime normalizeMtime(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  NoteFsSignatures normalized() {
    return NoteFsSignatures(
      metaModifiedAt: normalizeMtime(metaModifiedAt),
      markdownModifiedAt: normalizeMtime(markdownModifiedAt),
      attachmentsModifiedAt: attachmentsModifiedAt == null
          ? null
          : normalizeMtime(attachmentsModifiedAt!),
    );
  }

  bool matches(NoteFsSignatures other) {
    final a = normalized();
    final b = other.normalized();
    return a.metaModifiedAt == b.metaModifiedAt &&
        a.markdownModifiedAt == b.markdownModifiedAt &&
        a.attachmentsModifiedAt == b.attachmentsModifiedAt;
  }
}

/// Reads `meta.json`, `note.md`, and newest attachment mtime for [noteId].
Future<NoteFsSignatures?> readNoteFsSignatures(
  MeshPadPaths paths,
  String noteId,
) async {
  final noteDir = paths.noteDir(noteId);
  final metaFile = File(p.join(noteDir, 'meta.json'));
  final mdFile = File(p.join(noteDir, 'note.md'));
  if (!await metaFile.exists() || !await mdFile.exists()) {
    return null;
  }

  final metaModifiedAt = (await metaFile.stat()).modified.toUtc();
  final markdownModifiedAt = (await mdFile.stat()).modified.toUtc();

  DateTime? attachmentsModifiedAt;
  final attachmentsDir = Directory(paths.attachmentsDir(noteId));
  if (await attachmentsDir.exists()) {
    await for (final entity in attachmentsDir.list()) {
      if (entity is! File) continue;
      final modified = (await entity.stat()).modified.toUtc();
      if (attachmentsModifiedAt == null ||
          modified.isAfter(attachmentsModifiedAt)) {
        attachmentsModifiedAt = modified;
      }
    }
  }

  return NoteFsSignatures(
    metaModifiedAt: metaModifiedAt,
    markdownModifiedAt: markdownModifiedAt,
    attachmentsModifiedAt: attachmentsModifiedAt,
  ).normalized();
}
