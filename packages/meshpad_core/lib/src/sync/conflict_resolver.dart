import '../models/note_meta.dart';

/// Result of comparing local and remote note content during sync (PLAN §11.3.1).
enum MergeOutcome {
  appliedRemote,
  appliedLocal,
  createdConflictCopy,
  unchanged,
}

bool noteContentEquals({
  required NoteMeta local,
  required String localMarkdown,
  required NoteMeta remote,
  required String remoteMarkdown,
}) {
  return local.title == remote.title &&
      localMarkdown == remoteMarkdown &&
      local.deleted == remote.deleted &&
      local.tags.join(',') == remote.tags.join(',');
}

/// Resolves concurrent edits; LWW by [NoteMeta.updatedAt] unless timestamps tie.
MergeOutcome resolveNoteConflict({
  required NoteMeta local,
  required NoteMeta remote,
  required String localMarkdown,
  required String remoteMarkdown,
}) {
  if (noteContentEquals(
    local: local,
    localMarkdown: localMarkdown,
    remote: remote,
    remoteMarkdown: remoteMarkdown,
  )) {
    return MergeOutcome.unchanged;
  }

  if (local.updatedAt == remote.updatedAt) {
    return MergeOutcome.createdConflictCopy;
  }

  return remote.updatedAt.isAfter(local.updatedAt)
      ? MergeOutcome.appliedRemote
      : MergeOutcome.appliedLocal;
}
