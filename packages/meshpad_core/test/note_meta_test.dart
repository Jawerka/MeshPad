import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('NoteMeta round-trip JSON', () {
    final original = NoteMeta(
      schemaVersion: 1,
      id: '550e8400-e29b-41d4-a716-446655440000',
      title: 'Тест',
      createdAt: DateTime.utc(2026, 5, 29, 12),
      updatedAt: DateTime.utc(2026, 5, 29, 13),
      author: 'device-a',
      attachments: [
        AttachmentMeta(name: 'a.png', size: 100, mime: 'image/png'),
      ],
    );

    final restored = NoteMeta.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.attachments.length, 1);
  });

  test('LWW merge prefers newer updatedAt', () {
    final older = NoteMeta(
      schemaVersion: 1,
      id: 'x',
      title: 'old',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      author: 'a',
    );
    final newer = NoteMeta(
      schemaVersion: 1,
      id: 'x',
      title: 'new',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
      author: 'b',
    );

    final merged = mergeNoteMeta(older, newer);
    expect(merged?.title, 'new');
  });

  test('trash expires after 7 days', () {
    final deletedAt = DateTime.utc(2026, 5, 20);
    final now = DateTime.utc(2026, 5, 28);
    expect(isTrashExpired(deletedAt: deletedAt, now: now), isTrue);
  });
}
