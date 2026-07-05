/// Wire payload for `POST /meshpad/p2p/sync/cascade`.
class CascadeSyncRequest {
  const CascadeSyncRequest({
    this.excludePeerIds = const [],
    this.hopLimit = 0,
  });

  final List<String> excludePeerIds;
  final int hopLimit;

  factory CascadeSyncRequest.fromWire(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CascadeSyncRequest();
    }

    final ids = <String>[];
    final legacy = json['excludePeerId'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      ids.add(legacy);
    }
    final rawList = json['excludePeerIds'];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is! String || entry.isEmpty) continue;
        if (!ids.contains(entry)) ids.add(entry);
      }
    }

    final hopLimit = json['hopLimit'] as int? ?? 0;
    return CascadeSyncRequest(excludePeerIds: ids, hopLimit: hopLimit);
  }

  Map<String, dynamic> toWire() {
    return {
      if (excludePeerIds.isNotEmpty) 'excludePeerIds': excludePeerIds,
      if (excludePeerIds.length == 1) 'excludePeerId': excludePeerIds.single,
      if (hopLimit > 0) 'hopLimit': hopLimit,
    };
  }
}
