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

  Future<NoteFolder?> read(String id) async {
    final dir = Directory(notePath(id));
    if (!await dir.exists()) return null;

    final metaFile = File(p.join(dir.path, 'meta.json'));
    final mdFile = File(p.join(dir.path, 'note.md'));
    if (!await metaFile.exists() || !await mdFile.exists()) return null;

    final meta = NoteMeta.fromJson(
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
    );
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

  Future<List<String>> listNoteIds({bool includeDeleted = false}) async {
    final root = Directory(notesRoot);
    if (!await root.exists()) return [];

    final ids = <String>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final folder = await read(id);
      if (folder == null) continue;
      if (!includeDeleted && folder.meta.deleted) continue;
      ids.add(id);
    }
    return ids;
  }
}
