import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import '../sync_transport.dart';
import 'http_remote_sync_gateway.dart';
import 'lan_peer_server.dart';
import 'lan_sync_codec.dart';
import 'udp_lan_discovery.dart';

/// LAN sync transport over HTTP + UDP discovery (pre-libp2p MVP, PLAN §5).
class LanSyncTransport implements SyncTransport {
  LanSyncTransport({
    required Future<SyncEngine> Function() getEngine,
    required Future<LocalDeviceIdentity> Function() getIdentity,
    this.announceHost,
  })  : _getEngine = getEngine,
        _getIdentity = getIdentity;

  final Future<SyncEngine> Function() _getEngine;
  final Future<LocalDeviceIdentity> Function() _getIdentity;
  final String? announceHost;

  final _controller = StreamController<SyncTransportEvent>.broadcast();
  final _peers = <String, LanPeerEndpoint>{};

  LanPeerServer? _server;
  UdpLanDiscovery? _discovery;
  var _running = false;
  LocalDeviceIdentity? _identity;
  int? _httpPort;

  @override
  Stream<SyncTransportEvent> get events => _controller.stream;

  LanPeerEndpoint? endpointFor(String peerId) => _peers[peerId];

  /// Caches a peer endpoint (e.g. from trusted device record) for sync.
  void rememberEndpoint(LanPeerEndpoint endpoint) {
    _peers[endpoint.peerId] = endpoint;
  }

  Map<String, LanPeerEndpoint> get knownPeers => Map.unmodifiable(_peers);

  Future<void> setPairingOffer(PinPairingOffer? offer) async {
    await _ensureStarted();
    _server?.setPairingOffer(offer);
  }

  Future<void> _ensureStarted() async {
    if (_running) return;
    await start();
  }

  String? _announceHost;

  @override
  Future<void> start() async {
    if (_running) return;

    _identity = await _getIdentity();
    _announceHost = announceHost ?? await detectLanHost();
    _server = LanPeerServer(getEngine: _getEngine);
    _httpPort = await _server!.start();

    _discovery = UdpLanDiscovery()
      ..onPeerDiscovered = _handleAnnouncement
      ..start(buildAnnouncement: _buildAnnouncement);

    _running = true;
  }

  LanPeerAnnouncement _buildAnnouncement() {
    final identity = _identity!;
    return LanPeerAnnouncement(
      peerId: identity.peerId,
      displayName: identity.displayName,
      host: _announceHost!,
      httpPort: _httpPort!,
    );
  }

  void _handleAnnouncement(LanPeerAnnouncement announcement) {
    final localId = _identity?.peerId;
    if (localId == null || announcement.peerId == localId) return;

    final endpoint = LanPeerEndpoint.fromAnnouncement(announcement);
    final existing = _peers[announcement.peerId];
    _peers[announcement.peerId] = endpoint;

    if (existing == null ||
        existing.host != endpoint.host ||
        existing.httpPort != endpoint.httpPort) {
      _controller.add(
        PeerDiscovered(
          peerId: endpoint.peerId,
          displayName: endpoint.displayName,
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    await _discovery?.stop();
    await _server?.stop();
    _discovery = null;
    _server = null;
    _running = false;
  }

  @override
  Future<void> requestSync({String? peerId}) async {
    if (!_running) {
      _controller.add(
        SyncFailed(message: 'LAN transport не запущен'),
      );
      return;
    }

    if (peerId == null) {
      _controller.add(
        SyncFailed(message: 'Не указано устройство для синхронизации'),
      );
      return;
    }

    final resolved = _peers[peerId];
    if (resolved == null) {
      _controller.add(
        SyncFailed(message: 'Устройство $peerId не найдено в сети'),
      );
      return;
    }

    try {
      final engine = await _getEngine();
      final gateway = HttpRemoteSyncGateway(endpoint: resolved);
      final result = await engine.syncWithRemote(gateway);
      _controller.add(
        SyncCompleted(peerId: peerId, noteCount: result.total),
      );
    } catch (e) {
      _controller.add(
        SyncFailed(
          message: e is MeshPadException ? e.message : e.toString(),
        ),
      );
    }
  }

  Future<bool> confirmPairingOnPeer({
    required LanPeerEndpoint endpoint,
    required PinPairingConfirm confirm,
  }) async {
    final gateway = HttpRemoteSyncGateway(endpoint: endpoint);
    return gateway.confirmPairing(confirm);
  }

  Future<PinPairingOffer?> fetchPairingOffer(LanPeerEndpoint endpoint) {
    return HttpRemoteSyncGateway(endpoint: endpoint).fetchPairingOffer();
  }

  void dispose() {
    unawaited(stop());
    _controller.close();
  }
}
