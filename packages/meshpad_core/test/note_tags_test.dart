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

  test('tagAutocompleteSuggestions filters by prefix and committed', () {
    const all = ['work', 'ideas', 'personal'];
    final suggestions = tagAutocompleteSuggestions(
      allTags: all,
      text: 'wo, id',
      cursorOffset: 'wo, id'.length,
    );
    expect(suggestions, ['ideas']);
  });

  test('tagTokenBeforeCursor reads partial token', () {
    expect(tagTokenBeforeCursor('alpha, be', 9), 'be');
    expect(committedTagsBeforeCursor('alpha, be', 9), {'alpha'});
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
