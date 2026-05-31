import 'dart:async';



import 'package:meshpad_core/meshpad_core.dart';



import '../pairing_protocol.dart';

import '../sync_transport.dart';

import 'composite_lan_discovery.dart';

import 'http_remote_sync_gateway.dart';

import 'lan_broadcast.dart';
import 'lan_discovery.dart';

import 'lan_peer_server.dart';

import 'lan_sync_codec.dart';

import '../meshpad_log.dart';

import 'udp_lan_discovery.dart';



typedef RemoteTrustedHandler = Future<void> Function(PinPairingConfirm confirm);



/// LAN sync transport over HTTP + mDNS/UDP discovery (pre-libp2p MVP, PLAN §5).

class LanSyncTransport implements SyncTransport {

  LanSyncTransport({

    required Future<SyncEngine> Function() getEngine,

    required Future<LocalDeviceIdentity> Function() getIdentity,

    this.getDeviceStore,

    this.announceHost,

    this.onRemoteTrusted,

    this.onCascadeSync,

  })  : _getEngine = getEngine,

        _getIdentity = getIdentity;



  final Future<SyncEngine> Function() _getEngine;

  final Future<LocalDeviceIdentity> Function() _getIdentity;

  final Future<DeviceIdentityStore> Function()? getDeviceStore;

  final String? announceHost;

  final RemoteTrustedHandler? onRemoteTrusted;

  final CascadeSyncHandler? onCascadeSync;



  final _controller = StreamController<SyncTransportEvent>.broadcast();

  final _peers = <String, LanPeerEndpoint>{};



  LanPeerServer? _server;

  LanDiscovery? _discovery;

  var _running = false;

  LocalDeviceIdentity? _identity;

  int? _httpPort;



  @override

  Stream<SyncTransportEvent> get events => _controller.stream;



  LanPeerEndpoint? endpointFor(String peerId) => _peers[peerId];



  /// Caches a peer endpoint (e.g. from trusted device record) for sync.

  void rememberEndpoint(LanPeerEndpoint endpoint) {

    _peers[endpoint.peerId] = endpoint;

    MeshPadLog.lan(

      'remember endpoint ${endpoint.peerId} '

      '${endpoint.host}:${endpoint.httpPort}',

    );

  }



  /// Drops cached peer state after trust is revoked (PLAN §5.3).

  void forgetPeer(String peerId) {

    if (_peers.remove(peerId) != null) {

      MeshPadLog.lan('forget peer $peerId');

    }

  }



  Map<String, LanPeerEndpoint> get knownPeers => Map.unmodifiable(_peers);

  String? get localLanHost => _announceHost;

  int? get localHttpPort => _httpPort;



  Future<void> setPairingOffer(PinPairingOffer? offer) async {

    await _ensureStarted();

    _server?.setPairingOffer(offer);

    if (offer != null) {

      MeshPadLog.pairing(

        'pairing offer active for ${offer.peerId} pin=${offer.pin}',

      );

    } else {

      MeshPadLog.pairing('pairing offer cleared');

    }

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

    _server = LanPeerServer(

      getEngine: _getEngine,

      lookupTrustedPeer: getDeviceStore == null
          ? null
          : (peerId) async {
              final store = await getDeviceStore!();
              return store.trustedRecordFor(peerId);
            },

      onPairingConfirmed: _handlePairingConfirmed,

      onCascadeSyncRequested: onCascadeSync,

    );

    _httpPort = await _server!.start();



    _discovery = CompositeLanDiscovery();

    _discovery!.onPeerDiscovered = _handleAnnouncement;

    await _discovery!.start(buildAnnouncement: _buildAnnouncement);



    _running = true;

    MeshPadLog.lan(

      'transport started peer=${_identity!.peerId} '

      'host=$_announceHost http=$_httpPort',

    );

  }



  Future<void> _handlePairingConfirmed(PinPairingConfirm confirm) async {

    if (onRemoteTrusted == null) return;

    if (confirm.initiatorPeerId == null ||

        confirm.initiatorLanHost == null ||

        confirm.initiatorHttpPort == null) {

      MeshPadLog.pairing(

        'remote trust skipped: initiator endpoint missing in confirm',

      );

      return;

    }

    await onRemoteTrusted!(confirm);

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
    final merged = existing == null
        ? endpoint
        : LanPeerEndpoint(
            peerId: endpoint.peerId,
            displayName: endpoint.displayName,
            host: preferredLanHost(existing.host, endpoint.host),
            httpPort: endpoint.httpPort,
          );

    _peers[announcement.peerId] = merged;



    if (existing == null ||

        existing.host != merged.host ||

        existing.httpPort != merged.httpPort ||

        existing.displayName != merged.displayName) {

      MeshPadLog.discovery(

        'peer updated ${merged.peerId} ${merged.host}:${merged.httpPort}',

      );

      _controller.add(

        PeerDiscovered(

          peerId: merged.peerId,

          displayName: merged.displayName,

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

    MeshPadLog.lan('transport stopped');

  }



  /// Resolves a reachable endpoint: cache → discovery refresh → stored fallback.

  Future<LanPeerEndpoint?> resolvePeerEndpoint({

    required String peerId,

    LanPeerEndpoint? stored,

  }) async {

    await _ensureStarted();



    Future<LanPeerEndpoint?> probe(LanPeerEndpoint endpoint) async {

      final ok = await HttpRemoteSyncGateway(endpoint: endpoint).checkHealth();

      if (ok) {

        MeshPadLog.sync(

          'health ok ${endpoint.peerId} ${endpoint.host}:${endpoint.httpPort}',

        );

        return endpoint;

      }

      MeshPadLog.warn(
        'sync',
        'health failed ${endpoint.peerId} ${endpoint.host}:${endpoint.httpPort}',
      );

      return null;

    }



    final cached = _peers[peerId];

    if (cached != null) {

      final live = await probe(cached);

      if (live != null) return live;

      _peers.remove(peerId);

    }



    MeshPadLog.sync('refreshing discovery for $peerId');

    await _discovery?.refresh();

    await Future<void>.delayed(const Duration(milliseconds: 600));



    final discovered = _peers[peerId];

    if (discovered != null) {

      final live = await probe(discovered);

      if (live != null) return live;

    }



    if (stored != null) {
      final localHost = _announceHost;
      if (!shouldTryStoredLanEndpoint(
        storedHost: stored.host,
        localHost: localHost,
      )) {
        MeshPadLog.sync(
          'skip stored endpoint ${stored.host}:${stored.httpPort} '
          '(subnet differs from local $localHost)',
        );
      } else {
        MeshPadLog.sync(
          'trying stored endpoint ${stored.host}:${stored.httpPort}',
        );

        final live = await probe(stored);

        if (live != null) {
          _peers[peerId] = stored;
          return stored;
        }
      }
    }



    MeshPadLog.warn('sync', 'no reachable endpoint for $peerId');

    return null;

  }



  @override

  Future<void> requestSync({String? peerId}) async {

    if (!_running) {

      _controller.add(

        SyncFailed(

          peerId: peerId,

          message: 'LAN transport не запущен',

        ),

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

        SyncFailed(

          peerId: peerId,

          message: 'Устройство $peerId не найдено в сети',

        ),

      );

      return;

    }



    MeshPadLog.sync(

      'sync start with $peerId at ${resolved.host}:${resolved.httpPort}',

    );



    try {

      final engine = await _getEngine();

      final identity = await _getIdentity();

      final authToken = await _authTokenFor(peerId);

      final gateway = HttpRemoteSyncGateway(

        endpoint: resolved,

        callerPeerId: identity.peerId,

        authToken: authToken,

      );

      final result = await engine.syncWithRemote(gateway);

      MeshPadLog.sync(

        'sync done $peerId pulled=${result.pulled} '

        'pushed=${result.receivedByPeer} ack=${result.acknowledged}',

      );

      _controller.add(

        SyncCompleted(peerId: peerId, noteCount: result.total),

      );

    } catch (e) {
      if (e is HttpRemoteSyncException &&
          (e.statusCode == 401 || e.statusCode == 403)) {
        forgetPeer(peerId);
      }

      final message = e is MeshPadException
          ? e.message
          : e is HttpRemoteSyncException
              ? _httpSyncErrorMessage(e)
              : e.toString();

      MeshPadLog.warn('sync', 'sync failed $peerId: $message');

      _controller.add(

        SyncFailed(peerId: peerId, message: message),

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



  Future<HttpRemoteSyncGateway> gatewayForPeer(String peerId) async {

    final endpoint = _peers[peerId];

    if (endpoint == null) {

      throw StateError('no endpoint for $peerId');

    }

    final identity = await _getIdentity();

    final authToken = await _authTokenFor(peerId);

    return HttpRemoteSyncGateway(

      endpoint: endpoint,

      callerPeerId: identity.peerId,

      authToken: authToken,

    );

  }



  Future<PinPairingOffer?> fetchPairingOffer(LanPeerEndpoint endpoint) {

    return HttpRemoteSyncGateway(endpoint: endpoint).fetchPairingOffer();

  }



  /// Re-advertises on LAN after the local display name changes.

  Future<void> refreshLocalDisplayName(String displayName) async {

    final trimmed = displayName.trim();

    if (trimmed.isEmpty) return;



    final current = _identity ?? await _getIdentity();

    if (trimmed == current.displayName) return;



    _identity = LocalDeviceIdentity(

      peerId: current.peerId,

      displayName: trimmed,

      icon: current.icon,

      createdAt: current.createdAt,

    );



    if (!_running || _discovery == null) return;



    await _discovery!.stop();

    await _discovery!.start(buildAnnouncement: _buildAnnouncement);

    MeshPadLog.lan('local display name updated to $trimmed');

  }



  Future<String?> _authTokenFor(String peerId) async {
    final loader = getDeviceStore;
    if (loader == null) return null;
    final store = await loader();
    return store.authTokenForPeer(peerId);
  }

  String _httpSyncErrorMessage(HttpRemoteSyncException e) {
    return switch (e.statusCode) {
      401 => 'Синхронизация отклонена: неверный ключ. Пересопрягите устройства.',
      403 => 'Синхронизация отклонена: устройство не доверено.',
      _ => e.toString(),
    };
  }



  void dispose() {

    unawaited(stop());

    _controller.close();

  }

}



Future<bool> probeLanPeerHealth(LanPeerEndpoint endpoint) =>

    HttpRemoteSyncGateway(endpoint: endpoint).checkHealth();


