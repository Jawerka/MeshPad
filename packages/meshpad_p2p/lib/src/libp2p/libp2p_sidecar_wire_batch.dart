/// Wire sync batch envelope ([SYNC_WIRE.md] § libp2p batch, PLAN 8.1).
class WireSyncBatch {
  const WireSyncBatch({
    this.version = 1,
    this.catalog = const [],
    this.notes = const [],
    this.attachments = const [],
  });

  final int version;
  final List<Map<String, dynamic>> catalog;
  final List<Map<String, dynamic>> notes;
  final List<WireBatchAttachment> attachments;

  factory WireSyncBatch.fromJson(Map<String, dynamic> json) {
    return WireSyncBatch(
      version: json['version'] as int? ?? 1,
      catalog: _mapList(json['catalog']),
      notes: _mapList(json['notes']),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => WireBatchAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'catalog': catalog,
        'notes': notes,
        'attachments': [for (final a in attachments) a.toJson()],
      };

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class WireBatchAttachment {
  const WireBatchAttachment({
    required this.noteId,
    required this.name,
    required this.bytesBase64,
    this.sha256,
  });

  final String noteId;
  final String name;
  final String bytesBase64;
  final String? sha256;

  factory WireBatchAttachment.fromJson(Map<String, dynamic> json) {
    return WireBatchAttachment(
      noteId: json['note_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bytesBase64: json['bytes_base64'] as String? ?? '',
      sha256: json['sha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'note_id': noteId,
        'name': name,
        'bytes_base64': bytesBase64,
        if (sha256 != null) 'sha256': sha256,
      };
}
