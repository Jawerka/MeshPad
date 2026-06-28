import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/note_meta.dart';

/// Saved remote version when sync detects a concurrent edit (PLAN §11.3.1).
class NoteConflictCopy {
  const NoteConflictCopy({
    required this.fileName,
    required this.savedAt,
    required this.remoteTitle,
    required this.remoteAuthor,
  });

  final String fileName;
  final DateTime savedAt;
  final String remoteTitle;
  final String remoteAuthor;
}

/// Reads/writes `notes/<id>/<id>.conflict-<ts>.md` with JSON front matter (PLAN §11.3.1).
class NoteConflictCopyStore {
  NoteConflictCopyStore({required this.noteDir});

  final String noteDir;

  static String fileNameFor(String noteId, DateTime savedAt) {
    final stamp = savedAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    return '$noteId.conflict-$stamp.md';
  }

  static bool isConflictFileName(String name) =>
      name.contains('.conflict-') && name.endsWith('.md');

  Future<void> write({
    required String noteId,
    required NoteMeta remoteMeta,
    required String remoteMarkdown,
    DateTime? savedAt,
  }) async {
    final at = savedAt ?? DateTime.now().toUtc();
    await Directory(noteDir).create(recursive: true);
    final name = fileNameFor(noteId, at);
    final body = _encode(
      title: remoteMeta.title,
      author: remoteMeta.author,
      savedAt: at,
      markdown: remoteMarkdown,
    );
    await File(p.join(noteDir, name)).writeAsString(body);
  }

  Future<List<NoteConflictCopy>> list() async {
    final dir = Directory(noteDir);
    if (!await dir.exists()) return [];

    final copies = <NoteConflictCopy>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      final parsed = _decode(await entity.readAsString());
      if (parsed == null) continue;
      copies.add(
        NoteConflictCopy(
          fileName: p.basename(entity.path),
          savedAt: parsed.savedAt,
          remoteTitle: parsed.title,
          remoteAuthor: parsed.author,
        ),
      );
    }
    copies.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return copies;
  }

  Future<({String title, String author, DateTime savedAt, String markdown})?>
      read(String fileName) async {
    final file = File(p.join(noteDir, fileName));
    if (!await file.exists()) return null;
    return _decode(await file.readAsString());
  }

  Future<void> delete(String fileName) async {
    final file = File(p.join(noteDir, fileName));
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final dir = Directory(noteDir);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (isConflictFileName(p.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  static String _encode({
    required String title,
    required String author,
    required DateTime savedAt,
    required String markdown,
  }) {
    final header = jsonEncode({
      'title': title,
      'author': author,
      'saved_at': savedAt.toUtc().toIso8601String(),
    });
    return '---\n$header\n---\n\n$markdown';
  }

  static ({String title, String author, DateTime savedAt, String markdown})?
      _decode(String raw) {
    final trimmed = raw.trimLeft();
    if (!trimmed.startsWith('---')) return null;
    final end = trimmed.indexOf('---', 3);
    if (end < 0) return null;
    final jsonBlock = trimmed.substring(3, end).trim();
    final body = trimmed.substring(end + 3).trimLeft();
    try {
      final map = jsonDecode(jsonBlock) as Map<String, dynamic>;
      return (
        title: map['title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        savedAt: DateTime.parse(map['saved_at'] as String).toUtc(),
        markdown: body,
      );
    } on Object {
      return null;
    }
  }
}
