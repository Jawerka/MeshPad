import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';

import '../sync_transport.dart';

import 'composite_lan_discovery.dart';

import 'http_remote_sync_gateway.dart';

import 'lan_broadcast.dart';
import 'lan_discovery.dart';

import 'lan_discovered_peer_policy.dart';

import 'lan_network_profile.dart';

import 'lan_peer_server.dart';

import 'lan_sync_codec.dart';
import 'lan_sync_wire_bytes.dart';

import 'lan_tls_identity.dart';

import '../meshpad_log.dart';

import 'mdns_lan_discovery.dart';
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
    this.enableTls = true,
    this.networkProfile = LanNetworkProfile.normal,
    this.outboundOnly = false,
  })  : _getEngine = getEngine,
        _getIdentity = getIdentity;

  final Future<SyncEngine> Function() _getEngine;

  final Future<LocalDeviceIdentity> Function() _getIdentity;

  final Future<DeviceIdentityStore> Function()? getDeviceStore;

  final String? announceHost;

  final RemoteTrustedHandler? onRemoteTrusted;

  final CascadeSyncHandler? onCascadeSync;

  final bool enableTls;

  final LanNetworkProfile networkProfile;

  /// Outbound HTTP client only — no local [LanPeerServer] or discovery.
  final bool outboundOnly;

  final _controller = StreamController<SyncTransportEvent>.broadcast();

  final _peers = <String, LanPeerEndpoint>{};

  final _peerLastSeen = <String, DateTime>{};

  Timer? _pruneTimer;

  LanPeerServer? _server;

  LanDiscovery? _discovery;

  var _running = false;

  LocalDeviceIdentity? _identity;

  int? _httpPort;

  int? _tlsPort;

  LanTlsIdentity? _tlsIdentity;

  @override
  Stream<SyncTransportEvent> get events => _controller.stream;

  LanPeerEndpoint? endpointFor(String peerId) => _peers[peerId];

  /// Caches a peer endpoint (e.g. from trusted device record) for sync.

  void rememberEndpoint(LanPeerEndpoint endpoint) {
    _peers[endpoint.peerId] = endpoint;
    _peerLastSeen[endpoint.peerId] = DateTime.now().toUtc();

    MeshPadLog.lan(
      'remember endpoint ${endpoint.peerId} '
      '${endpoint.host}:${endpoint.httpPort}',
    );
  }

  /// Drops cached peer state after trust is revoked (PLAN §5.3).

  void forgetPeer(String peerId) => _removePeer(peerId);

  Map<String, LanPeerEndpoint> get knownPeers => Map.unmodifiable(_peers);

  String? get localLanHost => _announceHost;

  int? get localHttpPort => _httpPort;

  int? get localTlsPort => _tlsPort;

  String? get localTlsCertSha256 => _tlsIdentity?.certSha256Hex;

  Future<void> setPairingOffer(PinPairingOffer? offer) async {
    if (outboundOnly) return;
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

    if (outboundOnly) {
      _running = true;
      MeshPadLog.lan(
        'outbound transport started peer=${_identity!.peerId} host=$_announceHost',
      );
      return;
    }

    if (enableTls && getDeviceStore != null) {
      final store = await getDeviceStore!();
      _tlsIdentity = await LanTlsIdentity.loadOrCreate(
        Directory(store.paths.tlsRoot),
      );
    }

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
      tlsIdentity: _tlsIdentity,
    );

    _httpPort = await _server!.start();

    _tlsPort = _server!.tlsPort;

    final profile = LanNetworkProfileSettings.forProfile(networkProfile);
    _discovery = CompositeLanDiscovery(
      mdns: MdnsLanDiscovery(
        browseInterval: profile.mdnsBrowseInterval,
        browseTimeout: profile.mdnsBrowseTimeout,
      ),
      udp: UdpLanDiscovery(
        announceInterval: profile.udpAnnounceInterval,
      ),
    );

    _discovery!.onPeerDiscovered = _handleAnnouncement;

    await _discovery!.start(buildAnnouncement: _buildAnnouncement);

    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(profile.mdnsBrowseInterval, (_) {
      _pruneStalePeers();
    });

    _running = true;

    MeshPadLog.lan(
      'transport started peer=${_identity!.peerId} '
      'host=$_announceHost http=$_httpPort',
    );
  }

  Future<void> _handlePairingConfirmed(PinPairingConfirm confirm) async {
    final initiatorId = confirm.initiatorPeerId;

    if (initiatorId != null) {
      _controller.add(
        PairingConfirmedRemotely(
          initiatorPeerId: initiatorId,
          initiatorDisplayName: confirm.initiatorDisplayName,
        ),
      );
    }

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
      tlsPort: _tlsPort,
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
            tlsPort: endpoint.tlsPort ?? existing.tlsPort,
          );

    _peers[announcement.peerId] = merged;
    _peerLastSeen[merged.peerId] = DateTime.now().toUtc();
    _resolveHostCollisions(merged.host);
    _pruneStalePeers();

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
          lanHost: merged.host,
          httpPort: merged.httpPort,
        ),
      );
    }
  }

  void _removePeer(String peerId) {
    if (_peers.remove(peerId) == null) return;
    _peerLastSeen.remove(peerId);
    MeshPadLog.lan('forget peer $peerId');
    _controller.add(PeerExpired(peerId: peerId));
  }

  void _resolveHostCollisions(String host) {
    if (host.isEmpty) return;

    final onHost =
        _peers.entries.where((entry) => entry.value.host == host).toList();
    if (onHost.length <= 1) return;

    final keep = pickPreferredPeerOnHost(
      onHost,
      lastSeenByPeerId: _peerLastSeen,
    );
    for (final entry in onHost) {
      if (entry.key == keep.peerId) continue;
      _removePeer(entry.key);
    }
  }

  void _pruneStalePeers() {
    final ttl =
        LanNetworkProfileSettings.forProfile(networkProfile).discoveryPeerTtl;
    final stale = stalePeerIds(
      lastSeenByPeerId: _peerLastSeen,
      ttl: ttl,
      now: DateTime.now().toUtc(),
    ).toList();
    for (final peerId in stale) {
      _removePeer(peerId);
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;

    _pruneTimer?.cancel();
    _pruneTimer = null;

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
      final gateway = HttpRemoteSyncGateway(endpoint: endpoint);

      if (!await gateway.checkHealth(secure: false)) {
        MeshPadLog.warn(
          'sync',
          'health failed ${endpoint.peerId} ${endpoint.host}:${endpoint.httpPort}',
        );

        return null;
      }

      final enriched = await gateway.enrichEndpointFromHealth(endpoint);

      MeshPadLog.sync(
        'health ok ${enriched.peerId} ${enriched.host}:${enriched.httpPort}'
        '${enriched.tlsPort != null ? ' tls=${enriched.tlsPort}' : ''}',
      );

      return enriched;
    }

    final cached = _peers[peerId];

    if (cached != null) {
      final live = await probe(cached);

      if (live != null) return live;

      _peers.remove(peerId);
    }

    MeshPadLog.sync('refreshing discovery for $peerId');

    if (!outboundOnly) {
      await _discovery?.refresh();

      await Future<void>.delayed(const Duration(milliseconds: 600));

      final discovered = _peers[peerId];

      if (discovered != null) {
        final live = await probe(discovered);

        if (live != null) return live;
      }
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

    LanSyncWireBytes.beginSession();
    final syncStopwatch = Stopwatch()..start();
    try {
      final engine = await _getEngine();

      final gateway = await gatewayForPeer(peerId);

      final result = await engine.syncWithRemote(gateway);

      if (result.failedPushNoteIds.isNotEmpty) {
        await OutboxProcessor().recordOutboxRetriesForNoteIds(
          engine.notes,
          result.failedPushNoteIds,
        );
      }

      syncStopwatch.stop();
      MeshPadLog.metric(
          'sync_duration_ms', '${syncStopwatch.elapsedMilliseconds}');
      MeshPadLog.metric('sync_bytes', '${LanSyncWireBytes.sessionTotal}');

      MeshPadLog.sync(
        'sync done $peerId pulled=${result.pulled} '
        'pushed=${result.receivedByPeer} ack=${result.acknowledged}'
        '${result.failedPushNoteIds.isNotEmpty ? ' partialFail=${result.failedPushNoteIds.length}' : ''}',
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

    final tlsCertSha256 = await _tlsCertFor(peerId);

    Uint8List? signingPrivateKey;
    final loader = getDeviceStore;
    if (loader != null && identity.signingPublicKey != null) {
      final store = await loader();
      signingPrivateKey = await store.readSigningPrivateKey();
    }

    return HttpRemoteSyncGateway(
      endpoint: endpoint,
      callerPeerId: identity.peerId,
      authToken: authToken,
      tlsCertSha256: tlsCertSha256,
      signingPrivateKey: signingPrivateKey,
    );
  }

  Future<String?> fetchPeerTlsCertSha256(LanPeerEndpoint endpoint) async {
    final gateway = HttpRemoteSyncGateway(endpoint: endpoint);
    final enriched = await gateway.enrichEndpointFromHealth(endpoint);
    return HttpRemoteSyncGateway(endpoint: enriched).fetchTlsCertSha256();
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
      signingPublicKey: current.signingPublicKey,
      signingKeyAlgorithm: current.signingKeyAlgorithm,
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

  Future<String?> _tlsCertFor(String peerId) async {
    final loader = getDeviceStore;
    if (loader == null) return null;
    final store = await loader();
    final record = await store.trustedRecordFor(peerId);
    return record?.tlsCertSha256;
  }

  String _httpSyncErrorMessage(HttpRemoteSyncException e) {
    return switch (e.statusCode) {
      401 =>
        'Синхронизация отклонена: неверный ключ. Пересопрягите устройства.',
      403 => 'Синхронизация отклонена: устройство не доверено.',
      _ => e.toString(),
    };
  }

  /// Triggers an immediate mDNS/UDP browse (e.g. when opening «Устройства»).
  Future<void> refreshDiscovery() async {
    if (!_running) return;
    await _discovery?.refresh();
    _pruneStalePeers();
  }

  void dispose() {
    unawaited(stop());
    _controller.close();
  }
}

Future<bool> probeLanPeerHealth(LanPeerEndpoint endpoint) =>
    HttpRemoteSyncGateway(endpoint: endpoint).checkHealth();
