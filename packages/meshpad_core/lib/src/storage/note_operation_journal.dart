import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'meshpad_paths.dart';

/// Operation types appended under `operations/` (PLAN §3.4, wave 7.1).
enum NoteOperationType {
  createNote('create_note'),
  editNote('edit_note'),
  deleteNote('delete_note'),
  restoreNote('restore_note'),
  purgeNote('purge_note');

  const NoteOperationType(this.wireValue);

  final String wireValue;
}

/// Append-only FS journal: `<dataDir>/operations/<yyyy-mm>/<uuid>.jsonl`.
class NoteOperationJournal {
  NoteOperationJournal({
    required MeshPadPaths paths,
    Uuid? uuid,
  })  : _paths = paths,
        _uuid = uuid ?? const Uuid();

  final MeshPadPaths _paths;
  final Uuid _uuid;

  String operationsMonthDir(DateTime utc) {
    final month = utc.month.toString().padLeft(2, '0');
    return p.join(_paths.root, 'operations', '${utc.year}-$month');
  }

  /// Records one operation as a single-line `.jsonl` file.
  Future<void> record({
    required NoteOperationType type,
    required String noteId,
    required String device,
    DateTime? ts,
    int? revision,
    bool? deleted,
  }) async {
    final when = (ts ?? DateTime.now()).toUtc();
    final dir = Directory(operationsMonthDir(when));
    await dir.create(recursive: true);
    final entry = <String, dynamic>{
      'type': type.wireValue,
      'note_id': noteId,
      'device': device,
      'ts': when.toIso8601String(),
      if (revision != null) 'revision': revision,
      if (deleted != null) 'deleted': deleted,
    };
    final file = File(p.join(dir.path, '${_uuid.v4()}.jsonl'));
    await file.writeAsString('${jsonEncode(entry)}\n');
  }

  /// Lists operation files under [monthDir] (`yyyy-mm`), oldest first.
  Future<List<File>> listOperationFiles({String? monthDir}) async {
    final root = Directory(p.join(_paths.root, 'operations'));
    if (!await root.exists()) return [];

    final files = <File>[];
    if (monthDir != null) {
      final dir = Directory(p.join(root.path, monthDir));
      if (!await dir.exists()) return [];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          files.add(entity);
        }
      }
    } else {
      await for (final month in root.list()) {
        if (month is! Directory) continue;
        await for (final entity in month.list()) {
          if (entity is File && entity.path.endsWith('.jsonl')) {
            files.add(entity);
          }
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
