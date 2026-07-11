import 'package:meshpad_core/meshpad_core.dart';

import '../meshpad_log.dart';
import 'cascade_sync_request.dart';
import 'lan_single_peer_sync.dart';
import 'lan_sync_auth.dart';
import 'lan_sync_peer_order.dart';
import 'lan_sync_transport.dart';

enum LanSyncRunStatus { noPeers, completed, partial, failed }

class LanSyncRunResult {
  const LanSyncRunResult(
    this.status, {
    this.noteCount = 0,
    this.message,
    this.failedPeerIds = const [],
    this.succeededPeerIds = const [],
    this.skippedPeerIds = const [],
    this.peerAuthFailures = const {},
  });

  final LanSyncRunStatus status;
  final int noteCount;
  final String? message;
  final List<String> failedPeerIds;
  final List<String> succeededPeerIds;
  final List<String> skippedPeerIds;
  final Map<String, LanSyncAuthFailure> peerAuthFailures;
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
    List<String> excludePeerIds = const [],
    String? localPeerId,
    bool propagateCascade = true,
    int? hopLimit,
    int maxConcurrentPeers = 1,
    bool manageTransport = true,
    LanSyncPeerProgress? onPeerProgress,
  }) async {
    final allPeers = trusted ?? await deviceStore.listTrustedDevices();
    final excluded = {
      ...excludePeerIds,
      if (excludePeerId != null) excludePeerId,
    };
    var peers =
        allPeers.where((peer) => !excluded.contains(peer.peerId)).toList();

    if (peers.isEmpty) {
      MeshPadLog.sync('no trusted peers');
      return const LanSyncRunResult(
        LanSyncRunStatus.noPeers,
        message: 'Нет доверенных устройств',
      );
    }

    if (manageTransport) {
      await transport.start();
    }

    for (final peer in peers) {
      rememberPeerEndpoint(transport, peer);
    }

    peers = orderPeersForSync(peers: peers, transport: transport);

    final effectiveHopLimit = hopLimit ?? peers.length;
    final mayCascade = propagateCascade && effectiveHopLimit > 0;
    final concurrency = maxConcurrentPeers.clamp(1, peers.length);

    final batchStopwatch = Stopwatch()..start();
    try {
      var total = 0;
      var completedCount = 0;
      final succeededPeerIds = <String>[];
      final failedPeerIds = <String>[];
      final skippedPeerIds = <String>[];
      final failureMessages = <String>[];
      final peerAuthFailures = <String, LanSyncAuthFailure>{};

      Future<void> syncOnePeer(Device peer) async {
        onPeerProgress?.call(
          peer: peer,
          completed: completedCount,
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
          await deviceStore.clearAuthFailure(peer.peerId);
          if (mayCascade && localPeerId != null) {
            try {
              final gateway = await transport.gatewayForPeer(peer.peerId);
              final visited = <String>{
                ...excluded,
                localPeerId,
              }.toList(growable: false);
              await gateway.requestCascadeSync(
                CascadeSyncRequest(
                  excludePeerIds: visited,
                  hopLimit: effectiveHopLimit - 1,
                ),
              );
            } catch (e) {
              MeshPadLog.warn(
                'sync',
                'cascade request to ${peer.peerId} failed: $e',
              );
            }
          }
        } else if (peerResult.status == LanPeerSyncStatus.unreachable) {
          skippedPeerIds.add(peer.peerId);
          MeshPadLog.sync(
            'peer ${peer.peerId} offline, skipped',
          );
        } else {
          failedPeerIds.add(peer.peerId);
          if (peerResult.message != null) {
            failureMessages.add(peerResult.message!);
            final authFailure =
                parseLanSyncAuthFailureBody(peerResult.message!);
            if (authFailure != null) {
              peerAuthFailures[peer.peerId] = authFailure;
              await deviceStore.recordAuthFailure(
                peerId: peer.peerId,
                body: peerResult.message!,
              );
            }
          }
          MeshPadLog.warn(
            'sync',
            'peer ${peer.peerId} sync failed: ${peerResult.message}',
          );
        }

        completedCount++;
      }

      for (var index = 0; index < peers.length; index += concurrency) {
        final batch = peers.skip(index).take(concurrency).toList();
        if (batch.length == 1) {
          await syncOnePeer(batch.single);
        } else {
          await Future.wait(batch.map(syncOnePeer));
        }
      }

      if (peers.isNotEmpty) {
        onPeerProgress?.call(
          peer: peers.last,
          completed: peers.length,
          total: peers.length,
        );
      }

      batchStopwatch.stop();
      MeshPadLog.metric(
        'sync_duration_ms',
        '${batchStopwatch.elapsedMilliseconds}',
      );

      if (succeededPeerIds.isEmpty && failedPeerIds.isNotEmpty) {
        MeshPadLog.sync('sync batch failed all reachable peers');
        return LanSyncRunResult(
          LanSyncRunStatus.failed,
          message: failureMessages.isNotEmpty
              ? failureMessages.first
              : 'Синхронизация не удалась',
          failedPeerIds: failedPeerIds,
          succeededPeerIds: succeededPeerIds,
          skippedPeerIds: skippedPeerIds,
          peerAuthFailures: peerAuthFailures,
        );
      }

      if (failedPeerIds.isNotEmpty) {
        MeshPadLog.sync(
          'sync batch partial: ok=${succeededPeerIds.length} '
          'failed=${failedPeerIds.length} skipped=${skippedPeerIds.length} '
          'totalNotes=$total',
        );
        return LanSyncRunResult(
          LanSyncRunStatus.partial,
          noteCount: total,
          message: failureMessages.isNotEmpty ? failureMessages.first : null,
          failedPeerIds: failedPeerIds,
          succeededPeerIds: succeededPeerIds,
          skippedPeerIds: skippedPeerIds,
          peerAuthFailures: peerAuthFailures,
        );
      }

      MeshPadLog.sync(
        'sync batch completed totalNotes=$total '
        'skipped=${skippedPeerIds.length}',
      );
      return LanSyncRunResult(
        LanSyncRunStatus.completed,
        noteCount: total,
        succeededPeerIds: succeededPeerIds,
        skippedPeerIds: skippedPeerIds,
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
