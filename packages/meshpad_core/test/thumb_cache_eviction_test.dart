import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('evictThumbCache removes oldest files over limit', () async {
    final temp = await Directory.systemTemp.createTemp('meshpad_thumbs_');
    final noteDir = Directory(p.join(temp.path, 'note-1'));
    final thumbs = Directory(p.join(noteDir.path, '.thumbs'));
    await thumbs.create(recursive: true);

    final old = File(p.join(thumbs.path, 'a.jpg'));
    await old.writeAsBytes(List.filled(100 * 1024, 0));
    await old.setLastModified(DateTime(2020));

    final newer = File(p.join(thumbs.path, 'b.jpg'));
    await newer.writeAsBytes(List.filled(100 * 1024, 0));
    await newer.setLastModified(DateTime(2024));

    final result = await evictThumbCache(
      notesRoot: temp.path,
      maxBytes: 120 * 1024,
    );

    expect(result.removedFiles, 1);
    expect(await old.exists(), isFalse);
    expect(await newer.exists(), isTrue);
    expect(result.totalBytesAfter, lessThanOrEqualTo(120 * 1024));

    await temp.delete(recursive: true);
  });

  test('evictThumbCache no-op when under budget', () async {
    final temp = await Directory.systemTemp.createTemp('meshpad_thumbs_');
    final noteDir = Directory(p.join(temp.path, 'note-1'));
    final thumbs = Directory(p.join(noteDir.path, '.thumbs'));
    await thumbs.create(recursive: true);
    await File(p.join(thumbs.path, 'small.jpg')).writeAsBytes([1, 2, 3]);

    final result = await evictThumbCache(
      notesRoot: temp.path,
      maxBytes: 1024 * 1024,
    );

    expect(result.removedFiles, 0);
    expect(result.freedBytes, 0);

    await temp.delete(recursive: true);
  });
}
