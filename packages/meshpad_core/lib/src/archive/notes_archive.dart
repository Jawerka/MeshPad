import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/note_meta.dart';
import '../storage/meshpad_paths.dart';
import '../sync/lww_merge.dart';

const meshpadArchiveManifestVersion = 1;
const meshpadArchiveManifestName = 'meshpad-export.json';

/// Result of importing a MeshPad notes archive.
class NotesArchiveImportResult {
  const NotesArchiveImportResult({
    required this.imported,
    required this.skipped,
    required this.updated,
  });

  final int imported;
  final int skipped;
  final int updated;

  int get total => imported + skipped + updated;
}

/// Zip export/import for `notes/` (Phase E). Does not include `devices/` (secrets).
class NotesArchive {
  /// Writes all notes under [paths.notesRoot] to [zipPath].
  static Future<int> exportToFile({
    required MeshPadPaths paths,
    required String zipPath,
  }) async {
    final notesDir = Directory(paths.notesRoot);
    if (!await notesDir.exists()) {
      await _writeEmptyArchive(zipPath);
      return 0;
    }

    final noteIds = <String>[];
    await for (final entity in notesDir.list()) {
      if (entity is Directory) {
        noteIds.add(p.basename(entity.path));
      }
    }

    final manifest = {
      'version': meshpadArchiveManifestVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'note_count': noteIds.length,
    };

    final manifestBytes = utf8.encode(jsonEncode(manifest));
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          meshpadArchiveManifestName,
          manifestBytes.length,
          manifestBytes,
        ),
      );

    await for (final entity in notesDir.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: paths.root)
          .replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    await File(zipPath).writeAsBytes(zipBytes);
    return noteIds.length;
  }

  static Future<void> _writeEmptyArchive(String zipPath) async {
    final manifest = {
      'version': meshpadArchiveManifestVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'note_count': 0,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          meshpadArchiveManifestName,
          manifestBytes.length,
          manifestBytes,
        ),
      );
    final zipBytes = ZipEncoder().encode(archive);
    await File(zipPath).writeAsBytes(zipBytes);
  }

  /// Merges notes from [zipPath] into [paths.root] using LWW on `meta.json`.
  static Future<NotesArchiveImportResult> importFromFile({
    required MeshPadPaths paths,
    required String zipPath,
  }) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    var imported = 0;
    var skipped = 0;
    var updated = 0;

    final noteDirs = <String>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (name == meshpadArchiveManifestName) continue;
      if (!name.startsWith('notes/')) continue;
      final parts = name.split('/');
      if (parts.length >= 2) noteDirs.add(parts[1]);
    }

    for (final noteId in noteDirs) {
      final result = await _importNote(
        archive: archive,
        paths: paths,
        noteId: noteId,
      );
      switch (result) {
        case _NoteImportOutcome.imported:
          imported++;
        case _NoteImportOutcome.updated:
          updated++;
        case _NoteImportOutcome.skipped:
          skipped++;
      }
    }

    return NotesArchiveImportResult(
      imported: imported,
      skipped: skipped,
      updated: updated,
    );
  }

  static Future<_NoteImportOutcome> _importNote({
    required Archive archive,
    required MeshPadPaths paths,
    required String noteId,
  }) async {
    final prefix = 'notes/$noteId/';
    ArchiveFile? incomingMetaFile;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name.replaceAll('\\', '/') == '${prefix}meta.json') {
        incomingMetaFile = file;
        break;
      }
    }
    if (incomingMetaFile == null) return _NoteImportOutcome.skipped;

    final incomingMeta = NoteMeta.fromJson(
      jsonDecode(utf8.decode(incomingMetaFile.content)) as Map<String, dynamic>,
    );

    NoteMeta? localMeta;
    final localMetaPath = p.join(paths.noteDir(noteId), 'meta.json');
    if (await File(localMetaPath).exists()) {
      localMeta = NoteMeta.fromJson(
        jsonDecode(await File(localMetaPath).readAsString())
            as Map<String, dynamic>,
      );
    }

    final merged = mergeNoteMeta(localMeta, incomingMeta);
    if (merged == null || (localMeta != null && merged == localMeta)) {
      return _NoteImportOutcome.skipped;
    }

    final hadLocal = localMeta != null;
    final destDir = Directory(paths.noteDir(noteId));
    await destDir.create(recursive: true);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = file.name.replaceAll('\\', '/');
      if (!normalized.startsWith(prefix)) continue;

      final relative = normalized.substring(prefix.length);
      if (relative.isEmpty) continue;

      final outFile = File(p.join(destDir.path, relative));
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content);
    }

    return hadLocal ? _NoteImportOutcome.updated : _NoteImportOutcome.imported;
  }
}

enum _NoteImportOutcome { imported, updated, skipped }
