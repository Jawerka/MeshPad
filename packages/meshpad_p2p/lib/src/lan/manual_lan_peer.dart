import 'http_remote_sync_gateway.dart';
import 'lan_sync_codec.dart';
import '../meshpad_log.dart';
import '../pairing_protocol.dart';

/// Result of probing a manually entered LAN host (PLAN §11.4.2).
sealed class ManualLanPeerProbeResult {
  const ManualLanPeerProbeResult();
}

class ManualLanPeerProbeSuccess extends ManualLanPeerProbeResult {
  const ManualLanPeerProbeSuccess({
    required this.endpoint,
    this.pairingOffer,
  });

  final LanPeerEndpoint endpoint;
  final PinPairingOffer? pairingOffer;
}

enum ManualLanPeerProbeError {
  emptyHost,
  invalidPort,
  unreachable,
  webUnsupported,
}

class ManualLanPeerProbeFailure extends ManualLanPeerProbeResult {
  const ManualLanPeerProbeFailure(this.error);

  final ManualLanPeerProbeError error;
}

/// Checks HTTP health (and optional PIN offer) at [host]:[httpPort].
Future<ManualLanPeerProbeResult> probeManualLanPeer({
  required String host,
  required int httpPort,
}) async {
  final trimmedHost = host.trim();
  if (trimmedHost.isEmpty) {
    return const ManualLanPeerProbeFailure(ManualLanPeerProbeError.emptyHost);
  }
  if (httpPort <= 0 || httpPort > 65535) {
    return const ManualLanPeerProbeFailure(ManualLanPeerProbeError.invalidPort);
  }

  final probeEndpoint = LanPeerEndpoint(
    peerId: '_manual_probe',
    displayName: 'MeshPad',
    host: trimmedHost,
    httpPort: httpPort,
  );
  final gateway = HttpRemoteSyncGateway(endpoint: probeEndpoint);

  MeshPadLog.discovery('manual peer probe $trimmedHost:$httpPort');

  if (!await gateway.checkHealth(secure: false)) {
    return const ManualLanPeerProbeFailure(
      ManualLanPeerProbeError.unreachable,
    );
  }

  final enriched = await gateway.enrichEndpointFromHealth(probeEndpoint);
  if (enriched == null) {
    return const ManualLanPeerProbeFailure(
      ManualLanPeerProbeError.unreachable,
    );
  }
  final offer = await gateway.fetchPairingOffer();
  final peerId = offer?.peerId ?? 'manual-$trimmedHost-$httpPort';
  final displayName = offer?.displayName ?? 'MeshPad ($trimmedHost)';

  return ManualLanPeerProbeSuccess(
    endpoint: LanPeerEndpoint(
      peerId: peerId,
      displayName: displayName,
      host: enriched.host,
      httpPort: enriched.httpPort,
      tlsPort: enriched.tlsPort,
    ),
    pairingOffer: offer,
  );
}
