import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import '../meshpad_log.dart';
import '../sync_transport.dart';
import 'lan_sync_codec.dart';
import 'lan_sync_transport.dart';

enum LanSyncRunStatus { noPeers, completed, failed }

class LanSyncRunResult {
  const LanSyncRunResult(this.status, {this.noteCount = 0, this.message});

  final LanSyncRunStatus status;
  final int noteCount;
  final String? message;
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
      for (var index = 0; index < peers.length; index++) {
        final peer = peers[index];
        onPeerProgress?.call(
          peer: peer,
          completed: index,
          total: peers.length,
        );

        MeshPadLog.sync('sync trusted peer ${peer.peerId} (${peer.name})');

        final stored = peer.hasLanEndpoint
            ? LanPeerEndpoint(
                peerId: peer.peerId,
                displayName: peer.name,
                host: peer.lanHost!,
                httpPort: peer.lanHttpPort!,
              )
            : null;

        final endpoint = await transport.resolvePeerEndpoint(
          peerId: peer.peerId,
          stored: stored,
        );
        if (endpoint == null) {
          if (stored != null) {
            await deviceStore.clearLanEndpoint(peer.peerId);
          }
          throw SyncTransportException(
            'Устройство «${peer.name}» недоступно в сети. '
            'Проверьте Wi‑Fi и откройте MeshPad на обоих устройствах.',
          );
        }
        transport.rememberEndpoint(endpoint);

        final completer = Completer<SyncTransportEvent>();
        late final StreamSubscription<SyncTransportEvent> sub;
        sub = transport.events.listen((event) {
          if (event is SyncCompleted && event.peerId == peer.peerId) {
            if (!completer.isCompleted) completer.complete(event);
          } else if (event is SyncFailed &&
              (event.peerId == null || event.peerId == peer.peerId)) {
            if (!completer.isCompleted) completer.complete(event);
          }
        });

        await transport.requestSync(peerId: peer.peerId);
        final event = await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => SyncFailed(
            peerId: peer.peerId,
            message: 'Таймаут синхронизации',
          ),
        );
        await sub.cancel();

        if (event is SyncFailed) {
          throw SyncTransportException(event.message);
        }
        if (event is SyncCompleted) total += event.noteCount;

        await deviceStore.markPeerSeen(peer.peerId);
        final live = transport.endpointFor(peer.peerId);
        if (live != null) {
          await deviceStore.updateLanEndpoint(
            peerId: peer.peerId,
            lanHost: live.host,
            lanHttpPort: live.httpPort,
          );
        }

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
      }

      onPeerProgress?.call(
        peer: peers.last,
        completed: peers.length,
        total: peers.length,
      );

      batchStopwatch.stop();
      MeshPadLog.metric('sync_duration_ms', '${batchStopwatch.elapsedMilliseconds}');
      MeshPadLog.sync('sync batch completed totalNotes=$total');
      return LanSyncRunResult(LanSyncRunStatus.completed, noteCount: total);
    } catch (e) {
      if (e is! SyncTransportException) {
        await outboxProcessor.recordSyncFailure(repository);
      }
      final message = e is MeshPadException
          ? e.message
          : meshPadExceptionUserMessage(e);
      MeshPadLog.warn('sync', 'sync batch failed: $message');
      return LanSyncRunResult(
        LanSyncRunStatus.failed,
        message: message,
      );
    }
  }

  Future<void> rememberDiscoveredTrustedEndpoint({
    required LanSyncTransport transport,
    required String peerId,
  }) async {
    final trusted = await deviceStore.listTrustedDevices();
    if (!trusted.any((device) => device.peerId == peerId)) return;

    final endpoint = transport.endpointFor(peerId);
    if (endpoint == null) return;

    MeshPadLog.discovery(
      'update trusted endpoint $peerId ${endpoint.host}:${endpoint.httpPort}',
    );
    await deviceStore.updateLanEndpoint(
      peerId: peerId,
      lanHost: endpoint.host,
      lanHttpPort: endpoint.httpPort,
    );
  }
}

void rememberPeerEndpoint(LanSyncTransport transport, Device peer) {
  final live = transport.endpointFor(peer.peerId);
  if (live != null) return;

  if (peer.hasLanEndpoint) {
    transport.rememberEndpoint(
      LanPeerEndpoint(
        peerId: peer.peerId,
        displayName: peer.name,
        host: peer.lanHost!,
        httpPort: peer.lanHttpPort!,
      ),
    );
  }
}
