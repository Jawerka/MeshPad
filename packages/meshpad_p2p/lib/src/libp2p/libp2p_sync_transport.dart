import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import '../lan/lan_peer_server.dart';
import '../lan/lan_sync_codec.dart';
import '../lan/lan_sync_transport.dart';
import '../meshpad_log.dart';
import '../pairing_protocol.dart';
import '../sync_transport.dart';
import 'libp2p_native_api.dart';
import 'ffi_direct_libp2p_native_api.dart';
import 'http_libp2p_native_api.dart';
import 'http_sidecar_json_transport.dart';
import 'libp2p_sidecar_types.dart';
import 'sidecar_json_transport.dart';
import 'libp2p_sidecar_wire_client.dart';
import 'libp2p_peer_wire_registry.dart';
import 'sidecar_wire_remote_sync_gateway.dart';

/// [SyncTransport] entry point for libp2p (PLAN §12 B).
///
/// Sidecar wire data plane when available; otherwise [LanSyncTransport] (PLAN 8.3).
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
    this.useWireDataPlane = true,
    this.autoRegisterPeerWireBase = true,
    Libp2pPeerWireRegistry? peerWireRegistry,
  })  : _getEngine = getEngine,
        _getIdentity = getIdentity,
        _peerWireRegistry = peerWireRegistry ?? Libp2pPeerWireRegistry(),
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

  final Future<SyncEngine> Function() _getEngine;
  final Future<LocalDeviceIdentity> Function() _getIdentity;
  final Libp2pPeerWireRegistry _peerWireRegistry;
  final LanSyncTransport _lan;
  final Libp2pNativeApi? _nativeApi;
  final bool _trySidecar;

  /// When true and sidecar wire responds without LAN fallback, skip LAN [requestSync].
  final bool useWireDataPlane;

  /// Registers `http://<lan_host>:45839/` on [Libp2pNativePeerDiscovered] (PLAN 8.3 dev).
  final bool autoRegisterPeerWireBase;
  Libp2pNativeApi? _connectedNative;
  String? _sidecarBackend;
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

  /// When false, only the native sidecar is started (unit tests).
  @override
  Future<void> start({bool startLanStack = true}) async {
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
        if (native is FfiDirectLibp2pNativeApi) {
          final health = await native.fetchHealth();
          _sidecarBackend = health?.backend;
          MeshPadLog.lan('libp2p native transport: ffi_direct (no loopback HTTP)');
        } else if (native is HttpLibp2pNativeApi) {
          final health = await native.fetchHealth();
          _sidecarBackend = health?.backend;
        }
        MeshPadLog.lan(
          'libp2p sidecar connected'
          '${_sidecarBackend != null ? ' ($_sidecarBackend)' : ''}'
          '${useWireDataPlane ? '; wire data plane enabled' : '; LAN fallback only'}',
        );
      } catch (error) {
        _usingNative = false;
        MeshPadLog.lan('libp2p sidecar unavailable: $error');
      }
    } else {
      MeshPadLog.lan('libp2p transport: LAN fallback (sidecar not running)');
    }
    if (startLanStack) {
      await _lan.start();
      if (_usingNative && _activeNative != null) {
        _attachMergedEvents();
      }
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
      _sidecarBackend = null;
    }
    await _lan.stop();
    _running = false;
  }

  @override
  Future<void> requestSync({String? peerId}) async {
    if (peerId == null) {
      await _lan.requestSync(peerId: peerId);
      return;
    }

    if (_usingNative && useWireDataPlane && _hasSidecarWireNative) {
      final native = _activeNative!;
      try {
        await _pauseNativeEventsForWireSync();
        final remoteWireBase = _remoteWireBaseForSync(peerId);
        final sidecarSync = await _requestSidecarSyncWithResult(
          native: native,
          peerId: peerId,
          remoteWireBase: remoteWireBase,
        );
        if (remoteWireBase == null && _sidecarBackend == 'rust-libp2p') {
          MeshPadLog.lan(
            'libp2p sidecar sync $peerId via network '
            '(imported=${sidecarSync.wireImported} pushed=${sidecarSync.wirePushed} '
            'via=${sidecarSync.importVia ?? 'none'})',
          );
        }
        final result = await _syncViaSidecarWire(peerId: peerId, native: native);
        final wireActive = result.pulled > 0 ||
            result.receivedByPeer > 0 ||
            result.acknowledged > 0 ||
            sidecarSync.replicatedRemotely;
        if (!wireActive) {
          throw StateError(
            'sidecar wire sync produced no data for $peerId '
            '(import_via=${sidecarSync.importVia})',
          );
        }
        MeshPadLog.sync(
          'libp2p wire sync $peerId pulled=${result.pulled} '
          'pushed=${result.receivedByPeer} ack=${result.acknowledged}',
        );
        _emitSyncCompleted(peerId: peerId, noteCount: result.total);
        return;
      } catch (error) {
        MeshPadLog.lan('libp2p wire sync failed, LAN fallback: $error');
      } finally {
        await _resumeNativeEventsAfterWireSync();
      }
    } else if (_usingNative && _activeNative != null) {
      try {
        await _activeNative!.requestSync(peerId: peerId);
      } catch (error) {
        MeshPadLog.lan('libp2p sidecar sync ping failed: $error');
      }
    }

    await _lan.requestSync(peerId: peerId);
  }

  Future<void> _pauseNativeEventsForWireSync() async {
    await _nativeEventsSub?.cancel();
    _nativeEventsSub = null;
    final native = _activeNative;
    if (native is HttpLibp2pNativeApi) {
      await native.pauseEvents();
    } else if (native is FfiDirectLibp2pNativeApi) {
      await native.pauseEvents();
    }
  }

  Future<void> _resumeNativeEventsAfterWireSync() async {
    if (!_usingNative || _activeNative == null || _mergedEvents == null) return;
    final native = _activeNative;
    if (native is HttpLibp2pNativeApi) {
      await native.resumeEvents();
    } else if (native is FfiDirectLibp2pNativeApi) {
      await native.resumeEvents();
    }
    if (_nativeEventsSub != null) return;
    _nativeEventsSub = _activeNative!.events.listen(
      (event) => _mergedEvents!.add(_mapNativeEvent(event)),
      onError: _mergedEvents!.addError,
    );
  }

  bool get _hasSidecarWireNative =>
      _activeNative is HttpLibp2pNativeApi ||
      _activeNative is FfiDirectLibp2pNativeApi;

  Future<Libp2pSidecarSyncResult> _requestSidecarSyncWithResult({
    required Libp2pNativeApi native,
    required String peerId,
    String? remoteWireBase,
  }) {
    if (native is FfiDirectLibp2pNativeApi) {
      return native.requestSyncWithResult(
        peerId: peerId,
        remoteWireBase: remoteWireBase,
      );
    }
    if (native is HttpLibp2pNativeApi) {
      return native.requestSyncWithResult(
        peerId: peerId,
        remoteWireBase: remoteWireBase,
      );
    }
    throw StateError('unsupported native api for sidecar sync');
  }

  SidecarJsonTransport _wireTransportFor(Libp2pNativeApi native) {
    if (native is FfiDirectLibp2pNativeApi) {
      return native.jsonTransport;
    }
    if (native is HttpLibp2pNativeApi) {
      return HttpSidecarJsonTransport(baseUrl: native.baseUri.toString());
    }
    throw StateError('unsupported native api for wire transport');
  }

  Future<SyncSessionResult> _syncViaSidecarWire({
    required String peerId,
    required Libp2pNativeApi native,
  }) async {
    final wire = Libp2pSidecarWireClient(transport: _wireTransportFor(native));
    final probe = await wire.pushSnapshot(peerId: peerId, snapshot: {});
    if (probe.lanFallback) {
      throw StateError('sidecar wire still on LAN fallback');
    }

    final gateway = SidecarWireRemoteSyncGateway(client: wire, peerId: peerId);
    final engine = await _getEngine();
    return engine.syncWithRemote(gateway);
  }

  void _emitSyncCompleted({required String peerId, required int noteCount}) {
    final event = SyncCompleted(peerId: peerId, noteCount: noteCount);
    if (_mergedEvents != null && !_mergedEvents!.isClosed) {
      _mergedEvents!.add(event);
    }
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

  void forgetPeer(String peerId) {
    _peerWireRegistry.forget(peerId);
    _lan.forgetPeer(peerId);
  }

  /// Dev harness (PLAN 8.2): remote peer sidecar wire URL for [remote_wire_base].
  void rememberPeerWireBase(String peerId, String wireBaseUrl) {
    _peerWireRegistry.remember(peerId, wireBaseUrl);
  }

  String? peerWireBaseFor(String peerId) => _peerWireRegistry.wireBaseFor(peerId);

  String? remoteWireBaseFor(String peerId) =>
      _peerWireRegistry.remoteWireBaseFor(peerId);

  /// Explicit registry / env, or inferred URL on Dart sidecar only.
  String? _remoteWireBaseForSync(String peerId) {
    final explicit = _peerWireRegistry.remoteWireBaseFor(peerId);
    if (explicit != null) return explicit;
    if (_sidecarBackend == 'rust-libp2p') return null;
    if (!autoRegisterPeerWireBase) return null;
    return _peerWireRegistry.wireBaseFor(peerId);
  }

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
        :final wireBase,
      ) =>
        _rememberNativePeer(
          peerId: peerId,
          displayName: displayName,
          lanHost: lanHost,
          httpPort: httpPort,
          tlsPort: tlsPort,
          wireBase: wireBase,
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
    String? wireBase,
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
    if (autoRegisterPeerWireBase) {
      if (wireBase != null && wireBase.trim().isNotEmpty) {
        _peerWireRegistry.remember(peerId, wireBase.trim());
        MeshPadLog.lan('libp2p peer wire base $peerId → ${wireBase.trim()}');
      } else if (lanHost != null) {
        final resolved = inferPeerWireBase(lanHost: lanHost);
        if (resolved != null) {
          _peerWireRegistry.rememberInferred(peerId, resolved);
          MeshPadLog.lan('libp2p peer wire hint $peerId → $resolved (inferred)');
        }
      }
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
