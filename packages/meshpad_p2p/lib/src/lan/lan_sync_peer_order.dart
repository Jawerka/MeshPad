import 'package:meshpad_core/meshpad_core.dart';

import 'lan_sync_transport.dart';

bool isHubDisplayName(String name) => name.toLowerCase().contains('hub');

bool isPeerLikelyOnline(LanSyncTransport transport, Device peer) =>
    transport.endpointFor(peer.peerId) != null;

/// Orders peers for sync: online first, hub next, then most recently seen.
List<Device> orderPeersForSync({
  required List<Device> peers,
  required LanSyncTransport transport,
}) {
  final ordered = List<Device>.from(peers);
  ordered.sort((a, b) {
    final aOnline = isPeerLikelyOnline(transport, a);
    final bOnline = isPeerLikelyOnline(transport, b);
    if (aOnline != bOnline) return aOnline ? -1 : 1;

    final aHub = isHubDisplayName(a.name);
    final bHub = isHubDisplayName(b.name);
    if (aHub != bHub) return aHub ? -1 : 1;

    final aSeen =
        a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final bSeen =
        b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return bSeen.compareTo(aSeen);
  });
  return ordered;
}
