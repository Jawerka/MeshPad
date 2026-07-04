import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'sync_providers.dart';

final discoveredPeersProvider =
    NotifierProvider<DiscoveredPeersNotifier, List<DiscoveredPeer>>(
  DiscoveredPeersNotifier.new,
);

class DiscoveredPeersNotifier extends Notifier<List<DiscoveredPeer>> {
  @override
  List<DiscoveredPeer> build() => const [];

  void upsert(DiscoveredPeer peer) {
    final index = state.indexWhere((p) => p.peerId == peer.peerId);
    if (index >= 0) {
      final existing = state[index];
      if (existing.displayName == peer.displayName &&
          existing.lanHost == peer.lanHost &&
          existing.httpPort == peer.httpPort) {
        return;
      }
      final next = List<DiscoveredPeer>.of(state);
      next[index] = peer;
      state = next;
      return;
    }
    state = [...state, peer];
  }

  void remove(String peerId) {
    state = state.where((p) => p.peerId != peerId).toList();
  }
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class DiscoveryService {
  DiscoveryService(this._ref);

  final Ref _ref;
  StreamSubscription<SyncTransportEvent>? _eventsSub;

  bool get _supported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isAndroid);

  Future<void> start() => ensureRunning();

  /// Re-runs mDNS/UDP browse and syncs cached peers into the UI list.
  Future<void> refresh() async {
    if (!_supported) return;

    final transport = _ref.read(syncTransportProvider);
    _syncKnownPeers(transport);
    await transport.lanAccess?.refreshDiscovery();
  }

  /// Decodes a pairing QR and probes the host.
  Future<({PairingQrPayload payload, ManualLanPeerProbeSuccess probe})?>
      probePairingQr(String raw) async {
    final payload = PairingQrPayload.tryDecode(raw);
    if (payload == null) return null;

    final result = await probeManualPeer(
      host: payload.host,
      httpPort: payload.httpPort,
    );
    if (result is ManualLanPeerProbeSuccess) {
      return (payload: payload, probe: result);
    }
    return null;
  }

  /// Manual IP:port probe; adds peer to discovery list on success.
  Future<ManualLanPeerProbeResult> probeManualPeer({
    required String host,
    required int httpPort,
  }) async {
    if (!_supported) {
      return const ManualLanPeerProbeFailure(
        ManualLanPeerProbeError.webUnsupported,
      );
    }

    final result = await probeManualLanPeer(host: host, httpPort: httpPort);
    if (result is ManualLanPeerProbeSuccess) {
      final transport = _ref.read(syncTransportProvider);
      await transport.start();
      transport.lanAccess?.rememberEndpoint(result.endpoint);
      _ref.read(discoveredPeersProvider.notifier).upsert(
            DiscoveredPeer(
              peerId: result.endpoint.peerId,
              displayName: result.endpoint.displayName,
              discoveredAt: DateTime.now().toUtc(),
            ),
          );
    }
    return result;
  }

  /// Stops the current transport before [syncTransportProvider] is recreated.
  Future<void> prepareForTransportChange() async {
    if (!_supported) return;
    await _eventsSub?.cancel();
    _eventsSub = null;
    try {
      await _ref.read(syncTransportProvider).stop();
    } on Object {
      // Provider may already have disposed the previous instance.
    }
  }

  /// Stops listening, recycles transport, and starts discovery again.
  Future<void> restart() async {
    if (!_supported) return;
    await prepareForTransportChange();
    await ensureRunning();
  }

  Future<void> ensureRunning() async {
    if (!_supported) return;

    final transport = _ref.read(syncTransportProvider);
    try {
      await transport.start();
    } catch (e, st) {
      MeshPadLog.warn('discovery', 'transport.start failed: $e');
      MeshPadLog.warn('discovery', '$st');
      rethrow;
    }

    await _eventsSub?.cancel();
    _eventsSub = transport.events.listen(
      (event) async {
        if (event is PeerExpired) {
          _ref.read(discoveredPeersProvider.notifier).remove(event.peerId);
          return;
        }
        if (event is! PeerDiscovered) return;
        try {
          _ref.read(discoveredPeersProvider.notifier).upsert(
                DiscoveredPeer.fromEvent(event),
              );

          final lan = transport.lanAccess;
          if (lan == null) return;
          final coordinator =
              await _ref.read(lanSyncCoordinatorProvider.future);
          await coordinator.rememberDiscoveredTrustedEndpoint(
            transport: lan,
            peerId: event.peerId,
          );
        } catch (e, st) {
          MeshPadLog.warn('discovery', 'peer discovered handler failed: $e');
          MeshPadLog.warn('discovery', '$st');
        }
      },
      onError: (Object error, StackTrace st) {
        MeshPadLog.warn('discovery', 'transport events error: $error');
        MeshPadLog.warn('discovery', '$st');
      },
    );

    _syncKnownPeers(transport);
    await transport.lanAccess?.refreshDiscovery();
  }

  void _syncKnownPeers(SyncTransport transport) {
    final lan = transport.lanAccess;
    if (lan == null) return;
    final notifier = _ref.read(discoveredPeersProvider.notifier);
    for (final endpoint in lan.knownPeers.values) {
      notifier.upsert(
        DiscoveredPeer(
          peerId: endpoint.peerId,
          displayName: endpoint.displayName,
          discoveredAt: DateTime.now().toUtc(),
          lanHost: endpoint.host,
          httpPort: endpoint.httpPort,
        ),
      );
    }
  }

  void dispose() {
    unawaited(_eventsSub?.cancel());
  }
}

LanSyncTransport? readLanSyncTransport(WidgetRef ref) {
  return ref.read(syncTransportProvider).lanAccess;
}
