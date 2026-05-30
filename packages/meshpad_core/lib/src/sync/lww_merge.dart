import '../models/note_meta.dart';

/// Last-write-wins by [NoteMeta.updatedAt] (UTC).
NoteMeta? mergeNoteMeta(NoteMeta? local, NoteMeta? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  if (remote.updatedAt.isAfter(local.updatedAt)) return remote;
  if (remote.updatedAt.isBefore(local.updatedAt)) return local;
  // Equal timestamps: prefer tombstone, then remote for determinism.
  if (remote.deleted != local.deleted) {
    return remote.deleted ? remote : local;
  }
  return remote;
}

/// Returns true if [deletedAt] is older than [retention] from [now].
bool isTrashExpired({
  required DateTime deletedAt,
  required DateTime now,
  Duration retention = const Duration(days: 7),
}) {
  return now.difference(deletedAt) >= retention;
}
