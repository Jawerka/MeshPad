library;

import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

/// PLAN §11.1.4 — 1k benchmark: `dart test test/reconcile_benchmark_test.dart --tags benchmark`
void main() {
  Future<int> seedNotes(String dataDir, int count) async {
    final db = MeshPadDatabase.inMemory();
    final repo = createNoteRepository(
      dataDir: dataDir,
      defaultAuthor: 'bench',
      database: db,
    );
    for (var i = 0; i < count; i++) {
      await repo.createNote(
        title: 'Note $i',
        markdown: 'body $i',
      );
    }
    await db.close();
    return count;
  }

  Future<int> benchmarkReconcile(String dataDir) async {
    final db = MeshPadDatabase.inMemory();
    final repo = createNoteRepository(
      dataDir: dataDir,
      defaultAuthor: 'bench',
      database: db,
    );
    final stopwatch = Stopwatch()..start();
    final count = await repo.reconcileFromFilesystem();
    stopwatch.stop();
    await db.close();
    // ignore: avoid_print
    print(
      'reconcileFromFilesystem notes=$count '
      'duration_ms=${stopwatch.elapsedMilliseconds}',
    );
    return stopwatch.elapsedMilliseconds;
  }

  test('reconcile 1000 notes', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_bench_1k_');
    try {
      await seedNotes(dir.path, 1000);
      final ms = await benchmarkReconcile(dir.path);
      expect(ms, lessThan(120000),
          reason: '1k reconcile should finish < 2 min');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)), tags: ['benchmark']);

  test('reconcile 200 notes (CI smoke)', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_bench_200_');
    try {
      await seedNotes(dir.path, 200);
      final ms = await benchmarkReconcile(dir.path);
      expect(
        ms,
        lessThan(180000),
        reason: '200-note reconcile should finish < 3 min on CI',
      );
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
