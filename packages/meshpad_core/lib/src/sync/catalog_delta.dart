import '../models/note_head.dart';

/// Whether a remote catalog head requires fetching the full note body (PLAN §11.3.5).
bool noteHeadNeedsRemotePull({
  required NoteHead? localHead,
  required NoteHead remoteHead,
}) {
  if (localHead == null) return true;
  if (remoteHead.updatedAt.isAfter(localHead.updatedAt)) return true;
  if (remoteHead.updatedAt == localHead.updatedAt &&
      remoteHead.deleted != localHead.deleted) {
    return true;
  }
  return false;
}

/// Stats from a delta pull pass (for logs / tests).
class CatalogPullStats {
  const CatalogPullStats({
    this.catalogSize = 0,
    this.bodiesFetched = 0,
    this.bodiesSkipped = 0,
    this.applied = 0,
  });

  final int catalogSize;
  final int bodiesFetched;
  final int bodiesSkipped;
  final int applied;
}
