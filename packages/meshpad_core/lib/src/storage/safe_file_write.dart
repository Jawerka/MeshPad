import 'dart:async';
import 'dart:io';

/// Serializes work keyed by [key] (e.g. a directory path).
class DirectoryCreationLock {
  DirectoryCreationLock._();

  static final _pending = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() action) async {
    while (_pending.containsKey(key)) {
      await _pending[key];
    }
    final done = Completer<void>();
    _pending[key] = done.future;
    try {
      return await action();
    } finally {
      _pending.remove(key);
      if (!done.isCompleted) done.complete();
    }
  }
}

/// Writes [contents] to [file], tolerating Android scoped-storage EEXIST races.
Future<void> writeTextFileResilient(File file, String contents) async {
  await file.parent.create(recursive: true);

  for (var attempt = 0; attempt < 6; attempt++) {
    if (await file.exists()) {
      final existing = await file.readAsString();
      if (existing == contents) return;
    }

    try {
      await file.writeAsString(contents, flush: true);
      return;
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 17) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 40 * (attempt + 1)));
      if (await file.exists()) return;
    }
  }

  if (await file.exists()) return;
  throw FileSystemException('Failed to write ${file.path}');
}
