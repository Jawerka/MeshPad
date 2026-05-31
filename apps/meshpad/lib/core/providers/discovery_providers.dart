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
  LanDiscoverySimulator? _simulator;

  Future<void> start() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isAndroid)) {
      return;
    }

    final transport = _ref.read(syncTransportProvider);
    await transport.start();

    _eventsSub ??= transport.events.listen((event) async {
      if (event is! PeerDiscovered) return;
      _ref.read(discoveredPeersProvider.notifier).upsert(
            DiscoveredPeer.fromEvent(event),
          );

      if (transport is! LanSyncTransport) return;
      final coordinator = await _ref.read(lanSyncCoordinatorProvider.future);
      await coordinator.rememberDiscoveredTrustedEndpoint(
        transport: transport,
        peerId: event.peerId,
      );
    });

    if (transport is FakeSyncTransport) {
      _simulator ??= LanDiscoverySimulator(transport);
      _simulator!.start();
    }
  }

  void dispose() {
    unawaited(_eventsSub?.cancel());
    _simulator?.dispose();
  }
}

LanSyncTransport? readLanSyncTransport(WidgetRef ref) {
  final transport = ref.read(syncTransportProvider);
  return transport is LanSyncTransport ? transport : null;
}
