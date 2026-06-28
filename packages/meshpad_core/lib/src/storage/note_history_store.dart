import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_meta.dart';
import 'meshpad_paths.dart';

/// Writes a revision snapshot every [noteHistorySnapshotInterval] local saves (PLAN §7.2).
const int noteHistorySnapshotInterval = 10;

/// FS layout: `notes/<id>/history/<revision>/{meta.json, note.md}`.
class NoteHistoryStore {
  NoteHistoryStore({
    required MeshPadPaths paths,
    this.snapshotInterval = noteHistorySnapshotInterval,
  }) : _paths = paths;

  final MeshPadPaths _paths;
  final int snapshotInterval;

  String revisionDir(String noteId, int revision) =>
      _paths.noteHistoryRevisionDir(noteId, revision);

  /// Saves current note text/meta when [note.revision] is a non-zero multiple of [snapshotInterval].
  Future<bool> maybeSnapshot(Note note) async {
    final revision = note.revision;
    if (revision <= 0 || revision % snapshotInterval != 0) {
      return false;
    }

    final dir = Directory(revisionDir(note.id, revision));
    if (await dir.exists()) return false;

    await dir.create(recursive: true);
    final meta = note.toMeta();
    await File(p.join(dir.path, 'meta.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(meta.toJson()),
    );
    await File(p.join(dir.path, 'note.md')).writeAsString(note.markdown);
    return true;
  }

  /// Revision numbers that have snapshots, ascending.
  Future<List<int>> listRevisions(String noteId) async {
    final root = Directory(_paths.noteHistoryDir(noteId));
    if (!await root.exists()) return [];

    final revisions = <int>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final rev = int.tryParse(p.basename(entity.path));
      if (rev != null) revisions.add(rev);
    }
    revisions.sort();
    return revisions;
  }

  Future<NoteFolder?> readRevision(String noteId, int revision) async {
    final dir = Directory(revisionDir(noteId, revision));
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
}
