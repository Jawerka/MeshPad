import 'package:meshpad_core/meshpad_core.dart';

import '../meshpad_log.dart';
import 'lan_single_peer_sync.dart';
import 'lan_sync_transport.dart';

enum LanSyncRunStatus { noPeers, completed, partial, failed }

class LanSyncRunResult {
  const LanSyncRunResult(
    this.status, {
    this.noteCount = 0,
    this.message,
    this.failedPeerIds = const [],
    this.succeededPeerIds = const [],
  });

  final LanSyncRunStatus status;
  final int noteCount;
  final String? message;
  final List<String> failedPeerIds;
  final List<String> succeededPeerIds;
}

typedef LanSyncPeerProgress = void Function({
  required Device peer,
  required int completed,
  required int total,
});

/// Shared LAN sync loop for Flutter app and headless server.
class LanSyncCoordinator {
  LanSyncCoordinator({
    required this.deviceStore,
    OutboxProcessor? outboxProcessor,
  }) : outboxProcessor = outboxProcessor ?? OutboxProcessor();

  final DeviceIdentityStore deviceStore;
  final OutboxProcessor outboxProcessor;

  Future<LanSyncRunResult> syncTrustedPeers({
    required LanSyncTransport transport,
    required NoteRepository repository,
    List<Device>? trusted,
    String? excludePeerId,
    String? localPeerId,
    bool propagateCascade = true,
    LanSyncPeerProgress? onPeerProgress,
  }) async {
    final allPeers = trusted ?? await deviceStore.listTrustedDevices();
    final peers = excludePeerId == null
        ? allPeers
        : allPeers.where((peer) => peer.peerId != excludePeerId).toList();

    if (peers.isEmpty) {
      MeshPadLog.sync('no trusted peers');
      return const LanSyncRunResult(
        LanSyncRunStatus.noPeers,
        message: 'Нет доверенных устройств',
      );
    }

    final batchStopwatch = Stopwatch()..start();
    try {
      await transport.start();

      var total = 0;
      final succeededPeerIds = <String>[];
      final failedPeerIds = <String>[];
      final failureMessages = <String>[];

      for (var index = 0; index < peers.length; index++) {
        final peer = peers[index];
        onPeerProgress?.call(
          peer: peer,
          completed: index,
          total: peers.length,
        );

        MeshPadLog.sync('sync trusted peer ${peer.peerId} (${peer.name})');

        final peerResult = await syncSingleTrustedPeer(
          transport: transport,
          deviceStore: deviceStore,
          peer: peer,
        );

        if (peerResult.status == LanPeerSyncStatus.completed) {
          total += peerResult.noteCount;
          succeededPeerIds.add(peer.peerId);
          if (propagateCascade && localPeerId != null) {
            try {
              final gateway = await transport.gatewayForPeer(peer.peerId);
              await gateway.requestCascadeSync(
                excludePeerId: localPeerId,
              );
            } catch (e) {
              MeshPadLog.warn(
                'sync',
                'cascade request to ${peer.peerId} failed: $e',
              );
            }
          }
        } else {
          failedPeerIds.add(peer.peerId);
          if (peerResult.message != null) {
            failureMessages.add(peerResult.message!);
          }
          MeshPadLog.warn(
            'sync',
            'peer ${peer.peerId} sync skipped: ${peerResult.message}',
          );
        }
      }

      onPeerProgress?.call(
        peer: peers.last,
        completed: peers.length,
        total: peers.length,
      );

      batchStopwatch.stop();
      MeshPadLog.metric(
        'sync_duration_ms',
        '${batchStopwatch.elapsedMilliseconds}',
      );

      if (succeededPeerIds.isEmpty && failedPeerIds.isNotEmpty) {
        MeshPadLog.sync('sync batch failed all peers');
        return LanSyncRunResult(
          LanSyncRunStatus.failed,
          message: failureMessages.isNotEmpty
              ? failureMessages.first
              : 'Синхронизация не удалась',
          failedPeerIds: failedPeerIds,
          succeededPeerIds: succeededPeerIds,
        );
      }

      if (failedPeerIds.isNotEmpty) {
        MeshPadLog.sync(
          'sync batch partial: ok=${succeededPeerIds.length} '
          'failed=${failedPeerIds.length} totalNotes=$total',
        );
        return LanSyncRunResult(
          LanSyncRunStatus.partial,
          noteCount: total,
          message: failureMessages.isNotEmpty ? failureMessages.first : null,
          failedPeerIds: failedPeerIds,
          succeededPeerIds: succeededPeerIds,
        );
      }

      MeshPadLog.sync('sync batch completed totalNotes=$total');
      return LanSyncRunResult(
        LanSyncRunStatus.completed,
        noteCount: total,
        succeededPeerIds: succeededPeerIds,
      );
    } catch (e) {
      if (e is! SyncTransportException) {
        await outboxProcessor.recordSyncFailure(repository);
      }
      final message =
          e is MeshPadException ? e.message : meshPadExceptionUserMessage(e);
      MeshPadLog.warn('sync', 'sync batch failed: $message');
      return LanSyncRunResult(
        LanSyncRunStatus.failed,
        message: message,
      );
    }
  }

  Future<bool> rememberDiscoveredTrustedEndpoint({
    required LanSyncTransport transport,
    required String peerId,
  }) async {
    final trusted = await deviceStore.listTrustedDevices();
    if (!trusted.any((device) => device.peerId == peerId)) return false;

    final endpoint = transport.endpointFor(peerId);
    if (endpoint == null) return false;

    var changed = false;
    if (await deviceStore.syncRemoteDisplayNameIfAllowed(
      peerId: peerId,
      remoteDisplayName: endpoint.displayName,
    )) {
      changed = true;
    }

    MeshPadLog.discovery(
      'update trusted endpoint $peerId ${endpoint.host}:${endpoint.httpPort}',
    );
    await deviceStore.updateLanEndpoint(
      peerId: peerId,
      lanHost: endpoint.host,
      lanHttpPort: endpoint.httpPort,
    );
    return changed;
  }
}

void rememberPeerEndpoint(LanSyncTransport transport, Device peer) {
  final live = transport.endpointFor(peer.peerId);
  if (live != null) return;

  final stored = storedEndpointForPeer(peer);
  if (stored != null) {
    transport.rememberEndpoint(stored);
  }
}
