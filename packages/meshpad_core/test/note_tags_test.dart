import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeTags deduplicates and lowercases', () {
    expect(
      normalizeTags(['Work', 'work', ' IDEAS ', '']),
      ['work', 'ideas'],
    );
  });

  test('parseTagsInput splits on comma and space', () {
    expect(parseTagsInput('a, b; c'), ['a', 'b', 'c']);
  });

  test('NoteMeta round-trips tags', () {
    final meta = NoteMeta(
      schemaVersion: 1,
      id: 'id',
      title: 't',
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
      author: 'me',
      tags: const ['Alpha', 'beta'],
    );
    final json = meta.toJson();
    expect(json['tags'], ['alpha', 'beta']);

    final restored = NoteMeta.fromJson(json);
    expect(restored.tags, ['alpha', 'beta']);
  });
}
