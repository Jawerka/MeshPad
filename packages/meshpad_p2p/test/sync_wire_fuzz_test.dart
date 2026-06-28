import 'dart:convert';
import 'dart:math';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

final _random = Random(7);

Object? _randomJsonValue({int depth = 0}) {
  switch (_random.nextInt(depth > 3 ? 5 : 8)) {
    case 0:
      return _random.nextBool();
    case 1:
      return _random.nextInt(1000) - 500;
    case 2:
      return _randomString(_random.nextInt(12));
    case 3:
      return List.generate(
        _random.nextInt(4),
        (_) => _randomJsonValue(depth: depth + 1),
      );
    case 4:
      return {
        for (var i = 0; i < _random.nextInt(4); i++)
          _randomString(6): _randomJsonValue(depth: depth + 1),
      };
    case 5:
      return null;
    case 6:
      return _random.nextDouble();
    default:
      return _randomString(4);
  }
}

String _randomString(int len) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_-:/';
  return List.generate(len, (_) => chars[_random.nextInt(chars.length)]).join();
}

void main() {
  test('fuzz: tryParseCatalogJson never throws', () {
    for (var i = 0; i < 500; i++) {
      final encoded = jsonEncode(_randomJsonValue());
      Object? decoded;
      try {
        decoded = jsonDecode(encoded);
      } on Object {
        continue;
      }
      expect(() => tryParseCatalogJson(decoded), returnsNormally);
    }
  });

  test('fuzz: tryParseRemoteSnapshotJson never throws', () {
    for (var i = 0; i < 500; i++) {
      final encoded = jsonEncode(_randomJsonValue());
      Object? decoded;
      try {
        decoded = jsonDecode(encoded);
      } on Object {
        continue;
      }
      expect(() => tryParseRemoteSnapshotJson(decoded), returnsNormally);
    }
  });

  test('valid catalog round-trip', () {
    final heads = [
      NoteHead(
        id: '550e8400-e29b-41d4-a716-446655440000',
        updatedAt: DateTime.utc(2026, 5, 31, 12),
        deleted: false,
      ),
    ];
    final list = heads.map((h) => h.toJson()).toList();
    final parsed = tryParseCatalogJson(list);
    expect(parsed, isNotNull);
    expect(parsed!.single.id, heads.single.id);
  });

  test('valid snapshot round-trip', () {
    final meta = NoteMeta(
      schemaVersion: 1,
      id: '550e8400-e29b-41d4-a716-446655440000',
      title: 'Hi',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 5, 31),
      author: 'peer',
    );
    final json = remoteSnapshotToJson(
      RemoteNoteSnapshot(meta: meta, markdown: '# x'),
    );
    final parsed = tryParseRemoteSnapshotJson(json);
    expect(parsed?.meta.id, meta.id);
    expect(parsed?.markdown, '# x');
  });
}
