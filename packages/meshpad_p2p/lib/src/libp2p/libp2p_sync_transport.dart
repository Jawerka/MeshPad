import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import '../lan/lan_peer_server.dart';
import '../lan/lan_sync_codec.dart';
import '../lan/lan_sync_transport.dart';
import '../meshpad_log.dart';
import '../pairing_protocol.dart';
import '../sync_transport.dart';
import 'libp2p_native_api.dart';
import 'http_libp2p_native_api.dart';

/// [SyncTransport] entry point for libp2p (PLAN §12 B).
///
/// Until [Libp2pNativeApi] is wired (B.2), delegates to [LanSyncTransport].
class Libp2pSyncTransport implements SyncTransport {
  Libp2pSyncTransport({
    required Future<SyncEngine> Function() getEngine,
    required Future<LocalDeviceIdentity> Function() getIdentity,
    Future<DeviceIdentityStore> Function()? getDeviceStore,
    String? announceHost,
    RemoteTrustedHandler? onRemoteTrusted,
    CascadeSyncHandler? onCascadeSync,
    Libp2pNativeApi? nativeApi,
    bool trySidecar = true,
  })  : _getIdentity = getIdentity,
        _lan = LanSyncTransport(
          getEngine: getEngine,
          getIdentity: getIdentity,
          getDeviceStore: getDeviceStore,
          announceHost: announceHost,
          onRemoteTrusted: onRemoteTrusted,
          onCascadeSync: onCascadeSync,
        ),
        _nativeApi = nativeApi,
        _trySidecar = trySidecar;

  final Future<LocalDeviceIdentity> Function() _getIdentity;
  final LanSyncTransport _lan;
  final Libp2pNativeApi? _nativeApi;
  final bool _trySidecar;
  Libp2pNativeApi? _connectedNative;
  var _usingNative = false;
  StreamController<SyncTransportEvent>? _mergedEvents;
  StreamSubscription<SyncTransportEvent>? _lanEventsSub;
  StreamSubscription<Libp2pNativeEvent>? _nativeEventsSub;
  var _running = false;

  Libp2pNativeApi? get _activeNative => _nativeApi ?? _connectedNative;

  /// LAN fallback used while native libp2p is unavailable.
  LanSyncTransport get lanFallback => _lan;

  @override
  Stream<SyncTransportEvent> get events =>
      _mergedEvents?.stream ?? _lan.events;

  @override
  Future<void> start() async {
    Libp2pNativeApi? native = _nativeApi;
    if (native == null && _trySidecar) {
      native = await createLibp2pNativeApi();
    }

    if (native != null) {
      try {
        final identity = await _getIdentity();
        await native.start(
          peerId: identity.peerId,
          displayName: identity.displayName,
        );
        if (_nativeApi == null) {
          _connectedNative = native;
        }
        _usingNative = true;
        MeshPadLog.lan(
          'libp2p sidecar connected; sync still via LAN fallback until Rust push/pull',
        );
      } catch (error) {
        _usingNative = false;
        MeshPadLog.lan('libp2p sidecar unavailable: $error');
      }
    } else {
      MeshPadLog.lan('libp2p transport: LAN fallback (sidecar not running)');
    }
    await _lan.start();
    if (_usingNative && _activeNative != null) {
      _attachMergedEvents();
    }
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    await _detachMergedEvents();
    if (_usingNative) {
      await _activeNative?.stop();
      _usingNative = false;
      _connectedNative = null;
    }
    await _lan.stop();
    _running = false;
  }

  @override
  Future<void> requestSync({String? peerId}) async {
    if (_usingNative && _activeNative != null) {
      try {
        await _activeNative!.requestSync(peerId: peerId);
      } catch (error) {
        MeshPadLog.lan('libp2p sidecar sync ping failed: $error');
      }
    }
    await _lan.requestSync(peerId: peerId);
  }

  Future<void> setPairingOffer(PinPairingOffer? offer) => _lan.setPairingOffer(offer);

  Future<bool> confirmPairingOnPeer({
    required LanPeerEndpoint endpoint,
    required PinPairingConfirm confirm,
  }) =>
      _lan.confirmPairingOnPeer(endpoint: endpoint, confirm: confirm);

  Future<PinPairingOffer?> fetchPairingOffer(LanPeerEndpoint endpoint) =>
      _lan.fetchPairingOffer(endpoint);

  Future<void> refreshLocalDisplayName(String displayName) =>
      _lan.refreshLocalDisplayName(displayName);

  void forgetPeer(String peerId) => _lan.forgetPeer(peerId);

  void rememberEndpoint(LanPeerEndpoint endpoint) =>
      _lan.rememberEndpoint(endpoint);

  LanPeerEndpoint? endpointFor(String peerId) => _lan.endpointFor(peerId);

  String? get localLanHost => _lan.localLanHost;

  int? get localHttpPort => _lan.localHttpPort;

  Map<String, LanPeerEndpoint> get knownPeers => _lan.knownPeers;

  Future<LanPeerEndpoint?> resolvePeerEndpoint({
    required String peerId,
    LanPeerEndpoint? stored,
  }) =>
      _lan.resolvePeerEndpoint(peerId: peerId, stored: stored);

  void dispose() {
    unawaited(_detachMergedEvents());
    unawaited(stop());
    _lan.dispose();
  }

  SyncTransportEvent _mapNativeEvent(Libp2pNativeEvent event) {
    return switch (event) {
      Libp2pNativePeerDiscovered(
        :final peerId,
        :final displayName,
        :final lanHost,
        :final httpPort,
        :final tlsPort,
      ) =>
        _rememberNativePeer(
          peerId: peerId,
          displayName: displayName,
          lanHost: lanHost,
          httpPort: httpPort,
          tlsPort: tlsPort,
        ),
      Libp2pNativeSyncCompleted(:final peerId, :final noteCount) =>
        SyncCompleted(peerId: peerId, noteCount: noteCount),
      Libp2pNativeSyncFailed(:final peerId, :final message) =>
        SyncFailed(peerId: peerId, message: message),
    };
  }

  void _attachMergedEvents() {
    if (_mergedEvents != null) return;
    _mergedEvents = StreamController<SyncTransportEvent>.broadcast();
    _lanEventsSub = _lan.events.listen(
      _mergedEvents!.add,
      onError: _mergedEvents!.addError,
    );
    _nativeEventsSub = _activeNative!.events.listen(
      (event) => _mergedEvents!.add(_mapNativeEvent(event)),
      onError: _mergedEvents!.addError,
    );
  }

  Future<void> _detachMergedEvents() async {
    await _lanEventsSub?.cancel();
    await _nativeEventsSub?.cancel();
    _lanEventsSub = null;
    _nativeEventsSub = null;
    await _mergedEvents?.close();
    _mergedEvents = null;
  }

  PeerDiscovered _rememberNativePeer({
    required String peerId,
    required String displayName,
    String? lanHost,
    int? httpPort,
    int? tlsPort,
  }) {
    if (lanHost != null && httpPort != null) {
      _lan.rememberEndpoint(
        LanPeerEndpoint(
          peerId: peerId,
          displayName: displayName,
          host: lanHost,
          httpPort: httpPort,
          tlsPort: tlsPort,
        ),
      );
    }
    return PeerDiscovered(peerId: peerId, displayName: displayName);
  }
}

extension SyncTransportLanAccess on SyncTransport {
  /// Returns the underlying [LanSyncTransport] when available (LAN or libp2p fallback).
  LanSyncTransport? get lanAccess {
    if (this is LanSyncTransport) return this as LanSyncTransport;
    if (this is Libp2pSyncTransport) {
      return (this as Libp2pSyncTransport).lanFallback;
    }
    return null;
  }
}
