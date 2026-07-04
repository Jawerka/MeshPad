import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import '../meshpad_log.dart';
import '../sync_transport.dart';
import 'lan_sync_codec.dart';
import 'lan_sync_transport.dart';

/// Outcome of syncing with a single trusted peer.
enum LanPeerSyncStatus { completed, failed, unreachable }

class LanPeerSyncResult {
  const LanPeerSyncResult({
    required this.peerId,
    required this.status,
    this.noteCount = 0,
    this.message,
  });

  final String peerId;
  final LanPeerSyncStatus status;
  final int noteCount;
  final String? message;
}

LanPeerEndpoint? storedEndpointForPeer(Device peer) {
  if (!peer.hasLanEndpoint) return null;
  return LanPeerEndpoint(
    peerId: peer.peerId,
    displayName: peer.name,
    host: peer.lanHost!,
    httpPort: peer.lanHttpPort!,
  );
}

/// Resolves endpoint, runs sync session, updates device store on success.
Future<LanPeerSyncResult> syncSingleTrustedPeer({
  required LanSyncTransport transport,
  required DeviceIdentityStore deviceStore,
  required Device peer,
  Duration timeout = const Duration(seconds: 120),
}) async {
  final stored = storedEndpointForPeer(peer);

  final endpoint = await transport.resolvePeerEndpoint(
    peerId: peer.peerId,
    stored: stored,
  );
  if (endpoint == null) {
    if (stored != null) {
      await deviceStore.clearLanEndpoint(peer.peerId);
    }
    return LanPeerSyncResult(
      peerId: peer.peerId,
      status: LanPeerSyncStatus.unreachable,
      message: 'Устройство «${peer.name}» недоступно в сети. '
          'Проверьте Wi‑Fi и откройте MeshPad на обоих устройствах.',
    );
  }
  transport.rememberEndpoint(endpoint);

  final completer = Completer<SyncTransportEvent>();
  late final StreamSubscription<SyncTransportEvent> sub;
  sub = transport.events.listen(
    (event) {
      if (event is SyncCompleted && event.peerId == peer.peerId) {
        if (!completer.isCompleted) completer.complete(event);
      } else if (event is SyncFailed &&
          (event.peerId == null || event.peerId == peer.peerId)) {
        if (!completer.isCompleted) completer.complete(event);
      }
    },
    onError: (Object error, StackTrace st) {
      MeshPadLog.warn('sync', 'transport events error for ${peer.peerId}: $error');
      MeshPadLog.warn('sync', '$st');
      if (!completer.isCompleted) {
        completer.complete(
          SyncFailed(peerId: peer.peerId, message: error.toString()),
        );
      }
    },
  );

  try {
    await transport.requestSync(peerId: peer.peerId);
    final event = await completer.future.timeout(
      timeout,
      onTimeout: () => SyncFailed(
        peerId: peer.peerId,
        message: 'Таймаут синхронизации',
      ),
    );

    if (event is SyncFailed) {
      return LanPeerSyncResult(
        peerId: peer.peerId,
        status: LanPeerSyncStatus.failed,
        message: event.message,
      );
    }

    final noteCount = event is SyncCompleted ? event.noteCount : 0;
    await deviceStore.markPeerSeen(peer.peerId);
    final live = transport.endpointFor(peer.peerId);
    if (live != null) {
      await deviceStore.updateLanEndpoint(
        peerId: peer.peerId,
        lanHost: live.host,
        lanHttpPort: live.httpPort,
      );
    }

    return LanPeerSyncResult(
      peerId: peer.peerId,
      status: LanPeerSyncStatus.completed,
      noteCount: noteCount,
    );
  } catch (e) {
    MeshPadLog.warn('sync', 'peer ${peer.peerId} sync error: $e');
    return LanPeerSyncResult(
      peerId: peer.peerId,
      status: LanPeerSyncStatus.failed,
      message: e is MeshPadException
          ? e.message
          : meshPadExceptionUserMessage(e),
    );
  } finally {
    await sub.cancel();
  }
}
