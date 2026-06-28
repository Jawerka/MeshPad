import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

NoteMeta _meta(DateTime updatedAt, {String title = 't'}) => NoteMeta(
      schemaVersion: 2,
      id: 'note-1',
      title: title,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: updatedAt,
      author: 'device',
    );

void main() {
  final at = DateTime.utc(2026, 5, 31, 12);

  test('same timestamp different body → conflict copy', () {
    final outcome = resolveNoteConflict(
      local: _meta(at, title: 'A title'),
      remote: _meta(at, title: 'B title'),
      localMarkdown: 'body A',
      remoteMarkdown: 'body B',
    );
    expect(outcome, MergeOutcome.createdConflictCopy);
  });

  test('remote newer → appliedRemote', () {
    final outcome = resolveNoteConflict(
      local: _meta(at),
      remote: _meta(at.add(const Duration(hours: 1))),
      localMarkdown: 'old',
      remoteMarkdown: 'new',
    );
    expect(outcome, MergeOutcome.appliedRemote);
  });

  test('identical content → unchanged', () {
    final outcome = resolveNoteConflict(
      local: _meta(at),
      remote: _meta(at),
      localMarkdown: 'same',
      remoteMarkdown: 'same',
    );
    expect(outcome, MergeOutcome.unchanged);
  });
}
