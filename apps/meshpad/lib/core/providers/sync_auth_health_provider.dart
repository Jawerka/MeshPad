import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'notes_providers.dart';
import 'sync_providers.dart' show deviceStoreProvider;

/// Peers that returned 401/403 on the last sync attempt.
final peerSyncAuthFailedProvider = NotifierProvider<PeerSyncAuthFailedNotifier,
    Map<String, LanSyncAuthFailure>>(
  PeerSyncAuthFailedNotifier.new,
);

class PeerSyncAuthFailedNotifier
    extends Notifier<Map<String, LanSyncAuthFailure>> {
  @override
  Map<String, LanSyncAuthFailure> build() => const {};

  void recordFailure(String peerId, LanSyncAuthFailure failure) {
    state = {...state, peerId: failure};
  }

  void clearPeer(String peerId) {
    if (!state.containsKey(peerId)) return;
    final next = Map<String, LanSyncAuthFailure>.from(state)..remove(peerId);
    state = next;
  }

  void clearAll() => state = const {};
}

/// Whether the local signing key was reset and peers need re-pairing.
final syncAuthHealthProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(isWebClientProvider)) return false;
  final store = await ref.watch(deviceStoreProvider.future);
  return store.signingKeyNeedsRePair();
});
