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
    final without = state.where((p) => p.peerId != peer.peerId).toList();
    state = [...without, peer];
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
      !kIsWeb &&
      (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isAndroid);

  Future<void> start() => ensureRunning();

  /// Re-runs mDNS/UDP browse and syncs cached peers into the UI list.
  Future<void> refresh() async {
    if (!_supported) return;

    final transport = _ref.read(syncTransportProvider);
    _syncKnownPeers(transport);
    await transport.lanAccess?.refreshDiscovery();
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
    _eventsSub = transport.events.listen((event) async {
      if (event is! PeerDiscovered) return;
      _ref.read(discoveredPeersProvider.notifier).upsert(
            DiscoveredPeer.fromEvent(event),
          );

      final lan = transport.lanAccess;
      if (lan == null) return;
      final coordinator = await _ref.read(lanSyncCoordinatorProvider.future);
      await coordinator.rememberDiscoveredTrustedEndpoint(
        transport: lan,
        peerId: event.peerId,
      );
    });

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
