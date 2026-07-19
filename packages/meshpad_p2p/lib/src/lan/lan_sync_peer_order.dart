import 'package:meshpad_core/meshpad_core.dart';

import 'lan_broadcast.dart';
import 'lan_network_profile.dart';
import 'lan_single_peer_sync.dart';
import 'lan_sync_transport.dart';

bool isHubDisplayName(String name) => name.toLowerCase().contains('hub');

/// Whether [peer] is reachable now or has a recent stored LAN endpoint on this subnet.
bool isPeerLikelyOnline(
  LanSyncTransport transport,
  Device peer, {
  Duration discoveryPeerTtl = const Duration(minutes: 15),
}) {
  if (transport.endpointFor(peer.peerId) != null) return true;

  final stored = storedEndpointForPeer(
    peer,
    localLanHost: transport.localLanHost,
  );
  if (stored == null) return false;

  if (!shouldTryStoredLanEndpoint(
    storedHost: stored.host,
    localHost: transport.localLanHost,
  )) {
    return false;
  }

  final lastSeen = peer.lastSeenAt;
  if (lastSeen == null) return false;

  return DateTime.now().toUtc().difference(lastSeen.toUtc()) <=
      discoveryPeerTtl;
}

/// Orders peers for sync: online first, hub next, then most recently seen.
List<Device> orderPeersForSync({
  required List<Device> peers,
  required LanSyncTransport transport,
}) {
  final ttl = LanNetworkProfileSettings.forProfile(transport.networkProfile)
      .discoveryPeerTtl;
  final ordered = List<Device>.from(peers);
  ordered.sort((a, b) {
    final aOnline = isPeerLikelyOnline(transport, a, discoveryPeerTtl: ttl);
    final bOnline = isPeerLikelyOnline(transport, b, discoveryPeerTtl: ttl);
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
