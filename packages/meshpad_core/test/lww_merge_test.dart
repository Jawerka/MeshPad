import 'dart:math';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

NoteMeta _meta({
  required String id,
  required DateTime updatedAt,
  bool deleted = false,
}) {
  return NoteMeta(
    schemaVersion: 1,
    id: id,
    title: 't',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt,
    author: 'device',
    deleted: deleted,
  );
}

void main() {
  final random = Random(42);

  DateTime randomUtc(Random r) {
    final ms = r.nextInt(1 << 31);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  test('mergeNoteMeta agrees on winner when timestamps differ', () {
    for (var i = 0; i < 300; i++) {
      final id = 'note-${random.nextInt(1000)}';
      final a = _meta(id: id, updatedAt: randomUtc(random));
      final b = _meta(id: id, updatedAt: randomUtc(random));
      if (a.updatedAt == b.updatedAt) continue;

      final ab = mergeNoteMeta(a, b);
      final ba = mergeNoteMeta(b, a);
      expect(ab, isNotNull);
      expect(ba, isNotNull);
      expect(ab!.updatedAt, ba!.updatedAt);
      expect(ab.deleted, ba.deleted);
    }
  });

  test('mergeNoteMeta is associative for distinct timestamps', () {
    for (var i = 0; i < 200; i++) {
      final id = 'note-$i';
      final times = List.generate(3, (_) => randomUtc(random))..sort();
      if (times[0] == times[2]) continue;

      final a = _meta(id: id, updatedAt: times[0]);
      final b = _meta(id: id, updatedAt: times[1]);
      final c = _meta(id: id, updatedAt: times[2]);

      final left = mergeNoteMeta(a, mergeNoteMeta(b, c));
      final right = mergeNoteMeta(mergeNoteMeta(a, b), c);
      expect(left?.updatedAt, right?.updatedAt);
    }
  });

  test('mergeNoteMeta prefers tombstone on equal updatedAt', () {
    final at = DateTime.utc(2026, 5, 1, 12);
    final live = _meta(id: 'x', updatedAt: at, deleted: false);
    final tomb = _meta(id: 'x', updatedAt: at, deleted: true);
    final merged = mergeNoteMeta(live, tomb);
    expect(merged?.deleted, isTrue);
  });

  test('mergeNoteMeta handles null sides', () {
    final m = _meta(id: 'x', updatedAt: DateTime.utc(2026, 1, 2));
    expect(mergeNoteMeta(null, m), m);
    expect(mergeNoteMeta(m, null), m);
    expect(mergeNoteMeta(null, null), isNull);
  });
}
