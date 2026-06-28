import '../models/note_meta.dart';

/// Full note payload exchanged during sync.
class RemoteNoteSnapshot {
  const RemoteNoteSnapshot({
    required this.meta,
    required this.markdown,
  });

  final NoteMeta meta;
  final String markdown;
}

enum NoteApplyResult {
  applied,
  skippedLocalNewer,
  unchanged,
  conflictCopyCreated,
}
