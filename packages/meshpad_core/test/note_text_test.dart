import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('titleFromMarkdown prefers ATX heading', () {
    expect(
      titleFromMarkdown('# Список покупок\n\nмолоко'),
      'Список покупок',
    );
  });

  test('titleFromMarkdown uses first line when no heading', () {
    expect(titleFromMarkdown('Первая строка\nвторая'), 'Первая строка');
  });

  test('titleFromMarkdown returns empty for blank note', () {
    expect(titleFromMarkdown('\n  \n'), '');
  });

  test('resolveNoteTitle keeps current title when markdown has none', () {
    expect(
      resolveNoteTitle(currentTitle: 'Сохранённый', markdown: ''),
      'Сохранённый',
    );
  });

  test('resolveNoteTitle prefers explicit title', () {
    expect(
      resolveNoteTitle(
        currentTitle: 'old',
        markdown: '# new',
        explicitTitle: 'custom',
      ),
      'custom',
    );
  });

  test('defaultTitleFromCreatedAt formats local date time', () {
    final title = defaultTitleFromCreatedAt(DateTime.utc(2026, 6, 1, 9, 5));
    expect(title, matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'));
  });

  test('displayNoteTitle falls back to createdAt', () {
    final at = DateTime.utc(2026, 6, 1, 12, 0);
    expect(
      displayNoteTitle(title: '', markdown: '', createdAt: at),
      defaultTitleFromCreatedAt(at),
    );
  });
}
