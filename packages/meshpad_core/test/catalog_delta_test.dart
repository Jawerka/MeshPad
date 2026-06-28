import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 5, 31, 12);
  final local = NoteHead(id: 'n1', updatedAt: at, deleted: false);
  final newer = NoteHead(
    id: 'n1',
    updatedAt: at.add(const Duration(hours: 1)),
    deleted: false,
  );

  test('noteHeadNeedsRemotePull when remote is newer', () {
    expect(
      noteHeadNeedsRemotePull(localHead: local, remoteHead: newer),
      isTrue,
    );
  });

  test('noteHeadNeedsRemotePull skips matching heads', () {
    expect(
      noteHeadNeedsRemotePull(localHead: local, remoteHead: local),
      isFalse,
    );
  });

  test('noteHeadNeedsRemotePull when tombstone differs at same time', () {
    final remoteDeleted = NoteHead(id: 'n1', updatedAt: at, deleted: true);
    expect(
      noteHeadNeedsRemotePull(localHead: local, remoteHead: remoteDeleted),
      isTrue,
    );
  });

  test('mergeVectorClocks takes max per device', () {
    final merged = mergeVectorClocks(
      {'a': 2, 'b': 1},
      {'a': 1, 'b': 3},
    );
    expect(merged['a'], 2);
    expect(merged['b'], 3);
  });
}
