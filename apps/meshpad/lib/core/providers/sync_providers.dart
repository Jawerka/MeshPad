import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'notes_providers.dart';

final _outboxProcessor = OutboxProcessor();

final deviceStoreProvider = FutureProvider<DeviceIdentityStore>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw UnsupportedError('Device store unavailable on Web');
  }
  final dataDir = await ref.watch(dataDirProvider.future);
  return DeviceIdentityStore(paths: MeshPadPaths(dataDir!));
});

final localIdentityProvider = FutureProvider<LocalDeviceIdentity>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw UnsupportedError('Device identity unavailable on Web');
  }
  final store = await ref.watch(deviceStoreProvider.future);
  return store.loadOrCreateIdentity(defaultDisplayName: 'Это устройство');
});

final trustedDevicesProvider = FutureProvider<List<Device>>((ref) async {
  if (ref.watch(isWebClientProvider)) return [];
  final store = await ref.watch(deviceStoreProvider.future);
  return store.listTrustedDevices();
});

final syncEngineProvider = FutureProvider<SyncEngine>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw UnsupportedError('Sync engine unavailable on Web');
  }
  final repo = await ref.watch(noteRepositoryProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return SyncEngine(notes: repo, identity: identity);
});
final syncTransportProvider = Provider<FakeSyncTransport>((ref) {
  final transport = FakeSyncTransport();
  ref.onDispose(transport.dispose);
  return transport;
});

final noteSyncStatusesProvider =
    FutureProvider<Map<String, NoteSyncStatus>>((ref) async {
  if (ref.watch(isWebClientProvider)) return {};
  ref.watch(notesListProvider);
  final repo = await ref.watch(noteRepositoryProvider.future);
  return _outboxProcessor.statusMap(await repo.listOutbox());
});

final outboxFailedCountProvider = FutureProvider<int>((ref) async {
  if (ref.watch(isWebClientProvider)) return 0;
  final repo = await ref.watch(noteRepositoryProvider.future);
  return _outboxProcessor.failedCount(repo);
});

enum SyncRunStatus { noPeers, completed, failed }

class SyncRunResult {
  const SyncRunResult(this.status, {this.noteCount = 0, this.message});

  final SyncRunStatus status;
  final int noteCount;
  final String? message;
}

final syncControllerProvider = Provider<SyncController>((ref) {
  return SyncController(ref);
});

class SyncController {
  SyncController(this._ref);

  final Ref _ref;

  Future<SyncRunResult> runSync() async {
    if (_ref.read(isWebClientProvider)) {
      return const SyncRunResult(
        SyncRunStatus.noPeers,
        message: 'Синхронизация недоступна в Web-клиенте',
      );
    }
    final trusted = await _ref.read(trustedDevicesProvider.future);
    if (trusted.isEmpty) {
      return const SyncRunResult(
        SyncRunStatus.noPeers,
        message: 'Нет доверенных устройств',
      );
    }

    final repo = await _ref.read(noteRepositoryProvider.future);

    try {
      final transport = _ref.read(syncTransportProvider);
      await transport.start();

      var total = 0;
      for (final peer in trusted) {
        final eventFuture = transport.events.first;
        await transport.requestSync(peerId: peer.peerId);
        final event = await eventFuture;
        if (event is SyncCompleted) total += event.noteCount;
        final store = await _ref.read(deviceStoreProvider.future);
        await store.markPeerSeen(peer.peerId);
      }

      _invalidateSyncState();
      return SyncRunResult(SyncRunStatus.completed, noteCount: total);
    } catch (e) {
      await _outboxProcessor.recordSyncFailure(repo);
      _invalidateSyncState();
      final message = e is MeshPadException
          ? e.message
          : meshPadExceptionUserMessage(e);
      return SyncRunResult(
        SyncRunStatus.failed,
        message: message,
      );
    }
  }

  void _invalidateSyncState() {
    _ref.invalidate(outboxCountProvider);
    _ref.invalidate(pendingSyncNoteIdsProvider);
    _ref.invalidate(noteSyncStatusesProvider);
    _ref.invalidate(outboxFailedCountProvider);
    _ref.invalidate(notesListProvider);
    _ref.invalidate(trustedDevicesProvider);
  }
}
