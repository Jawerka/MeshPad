/// Lightweight catalog entry for sync (id + updated_at + tombstone).
class NoteHead {
  const NoteHead({
    required this.id,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final DateTime updatedAt;
  final bool deleted;

  bool isNewerThan(NoteHead? other) {
    if (other == null) return true;
    return updatedAt.isAfter(other.updatedAt);
  }
}
