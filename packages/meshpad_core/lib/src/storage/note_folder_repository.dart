import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/note_folder.dart';
import '../models/note_meta.dart';

/// File-system repository: `notes/<uuid>/{note.md, meta.json, attachments/}`.
class NoteFolderRepository {
  NoteFolderRepository({required this.notesRoot});

  final String notesRoot;

  String notePath(String id) => p.join(notesRoot, id);

  /// Reads only `meta.json` (cheap check when FS mtimes are unchanged).
  Future<NoteMeta?> readMeta(String id) async {
    final metaFile = File(p.join(notePath(id), 'meta.json'));
    if (!await metaFile.exists()) return null;
    return NoteMeta.fromJson(
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<NoteFolder?> read(String id) async {
    final dir = Directory(notePath(id));
    if (!await dir.exists()) return null;

    final metaFile = File(p.join(dir.path, 'meta.json'));
    final mdFile = File(p.join(dir.path, 'note.md'));
    if (!await metaFile.exists() || !await mdFile.exists()) return null;

    final meta = NoteMeta.fromJson(
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
    );
    if (meta.purged) return null;
    final markdown = await mdFile.readAsString();
    return NoteFolder(path: dir.path, meta: meta, markdown: markdown);
  }

  Future<void> write(NoteFolder folder) async {
    final dir = Directory(folder.path);
    await dir.create(recursive: true);
    await Directory(p.join(dir.path, 'attachments')).create(recursive: true);

    final metaFile = File(p.join(dir.path, 'meta.json'));
    final mdFile = File(p.join(dir.path, 'note.md'));

    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(folder.meta.toJson()),
    );
    await mdFile.writeAsString(folder.markdown);
  }

  Future<void> deleteNoteFolder(String id) async {
    final dir = Directory(notePath(id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes binary attachment and thumb dirs for [id] (soft-delete / free disk).
  Future<void> clearAttachmentDirs(String id) async {
    for (final name in ['attachments', '.thumbs']) {
      final sub = Directory(p.join(notePath(id), name));
      if (await sub.exists()) await sub.delete(recursive: true);
    }
  }

  /// Writes a permanent-delete tombstone (`meta.json` only, no body/attachments).
  Future<void> writePurgeTombstone(NoteMeta tombstone) async {
    assert(tombstone.purged);
    final dir = Directory(notePath(tombstone.id));
    await dir.create(recursive: true);

    final mdFile = File(p.join(dir.path, 'note.md'));
    if (await mdFile.exists()) await mdFile.delete();

    for (final name in ['attachments', '.thumbs', 'history']) {
      final sub = Directory(p.join(dir.path, name));
      if (await sub.exists()) await sub.delete(recursive: true);
    }

    final metaFile = File(p.join(dir.path, 'meta.json'));
    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(tombstone.toJson()),
    );
  }

  /// Directory names under [notesRoot] without reading note bodies.
  Future<List<String>> listNoteDirectoryIds() async {
    final root = Directory(notesRoot);
    if (!await root.exists()) return [];

    final ids = <String>[];
    await for (final entity in root.list()) {
      if (entity is Directory) {
        ids.add(p.basename(entity.path));
      }
    }
    return ids;
  }

  Future<List<String>> listNoteIds({bool includeDeleted = false}) async {
    final root = Directory(notesRoot);
    if (!await root.exists()) return [];

    final ids = <String>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final meta = await readMeta(id);
      if (meta == null) continue;
      if (meta.purged) continue;
      if (!includeDeleted && meta.deleted) continue;
      ids.add(id);
    }
    return ids;
  }
}
