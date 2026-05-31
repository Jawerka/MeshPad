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
}
