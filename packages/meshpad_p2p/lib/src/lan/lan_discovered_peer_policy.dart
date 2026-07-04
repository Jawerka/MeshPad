import 'lan_peer_server.dart';
import 'lan_sync_codec.dart';

/// Picks one peer when multiple [peerId]s were seen on the same LAN host.
///
/// Prefers the stable HTTP port, then the most recently seen announcement.
LanPeerEndpoint pickPreferredPeerOnHost(
  Iterable<MapEntry<String, LanPeerEndpoint>> onHost, {
  required Map<String, DateTime> lastSeenByPeerId,
  int preferredHttpPort = meshpadPreferredLanHttpPort,
}) {
  final entries = onHost.toList();
  if (entries.isEmpty) {
    throw ArgumentError('onHost must not be empty');
  }
  if (entries.length == 1) return entries.first.value;

  entries.sort((a, b) {
    final portA = a.value.httpPort == preferredHttpPort ? 1 : 0;
    final portB = b.value.httpPort == preferredHttpPort ? 1 : 0;
    if (portA != portB) return portB.compareTo(portA);

    final seenA =
        lastSeenByPeerId[a.key] ?? DateTime.fromMillisecondsSinceEpoch(0);
    final seenB =
        lastSeenByPeerId[b.key] ?? DateTime.fromMillisecondsSinceEpoch(0);
    return seenB.compareTo(seenA);
  });
  return entries.first.value;
}

/// Peer ids not seen since [ttl] relative to [now].
Iterable<String> stalePeerIds({
  required Map<String, DateTime> lastSeenByPeerId,
  required Duration ttl,
  required DateTime now,
}) sync* {
  final cutoff = now.toUtc().subtract(ttl);
  for (final entry in lastSeenByPeerId.entries) {
    if (entry.value.isBefore(cutoff)) yield entry.key;
  }
}
