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

  Map<String, dynamic> toJson() => {
        'id': id,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  factory NoteHead.fromJson(Map<String, dynamic> json) => NoteHead(
        id: json['id'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        deleted: json['deleted'] as bool? ?? false,
      );
}
