import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../constants/feature_flags.dart';
import '../platform/default_device_display_name.dart';
import '../sync/local_author_labels.dart';
import 'notes_providers.dart';
import 'sync_activity_provider.dart';

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
  return store.loadOrCreateIdentity(defaultDisplayName: defaultDeviceDisplayName());
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

final lanSyncCoordinatorProvider = FutureProvider<LanSyncCoordinator>((ref) async {
  final store = await ref.watch(deviceStoreProvider.future);
  return LanSyncCoordinator(deviceStore: store);
});

final syncTransportKindProvider = Provider<SyncTransportKind>((ref) {
  const fromEnv = String.fromEnvironment('MESHPAD_SYNC_TRANSPORT');
  if (fromEnv == 'libp2p') return SyncTransportKind.libp2p;

  final settings = ref.watch(appSettingsProvider);
  final fromSettings = settings.maybeWhen(
    data: (s) => s.syncTransportKind,
    orElse: () => SyncTransportKind.lan,
  );
  if (!MeshPadFeatureFlags.libp2pTransportSettingVisible &&
      fromSettings == SyncTransportKind.libp2p) {
    return SyncTransportKind.lan;
  }
  return fromSettings;
});

final syncTransportProvider = Provider<SyncTransport>((ref) {
  if (ref.watch(isWebClientProvider)) {
    final transport = FakeSyncTransport();
    ref.onDispose(transport.dispose);
    return transport;
  }

  const kind = String.fromEnvironment('MESHPAD_SYNC_TRANSPORT');
  final transportKind = kind == 'libp2p'
      ? SyncTransportKind.libp2p
      : ref.watch(syncTransportKindProvider);

  final engineFuture = ref.watch(syncEngineProvider.future);
  final identityFuture = ref.watch(localIdentityProvider.future);
  final deviceStoreFuture = ref.watch(deviceStoreProvider.future);

  final transport = createSyncTransport(
    kind: transportKind,
    getEngine: () => engineFuture,
    getIdentity: () => identityFuture,
    getDeviceStore: () => deviceStoreFuture,
    onRemoteTrusted: (confirm) async {
      final initiatorId = confirm.initiatorPeerId;
      final host = confirm.initiatorLanHost;
      final port = confirm.initiatorHttpPort;
      if (initiatorId == null || host == null || port == null) return;

      final store = await deviceStoreFuture;
      await store.trustDevice(
        peerId: initiatorId,
        name: confirm.initiatorDisplayName ?? 'Устройство',
        lanHost: host,
        lanHttpPort: port,
        authToken: confirm.authToken,
        tlsCertSha256: confirm.initiatorTlsCertSha256,
      );
      ref.invalidate(trustedDevicesProvider);
    },
    onCascadeSync: (excludePeerId) async {
      await ref.read(syncControllerProvider).runSync(
            excludePeerId: excludePeerId,
            propagateCascade: false,
          );
    },
  );
  ref.onDispose(transport.dispose);
  return transport;
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

/// Debounced sync after local note/outbox changes (not on Web).
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Side-effect: keep alive so note mutations trigger LAN sync.
final autoSyncOnNotesChangeProvider = Provider<void>((ref) {
  ref.listen<int>(pendingLocalSyncProvider, (previous, next) {
    if (previous == next) return;
    ref.read(syncSchedulerProvider).scheduleAfterLocalChange();
  });
});

class SyncScheduler {
  SyncScheduler(this._ref);

  final Ref _ref;
  Timer? _timer;

  void dispose() => _timer?.cancel();

  void scheduleAfterLocalChange() {
    if (_ref.read(isWebClientProvider)) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_ref.read(syncControllerProvider).runSync());
    });
  }
}

class SyncController {
  SyncController(this._ref);

  final Ref _ref;

  Future<SyncRunResult> runSync({
    String? excludePeerId,
    bool propagateCascade = true,
  }) async {
    if (_ref.read(isWebClientProvider)) {
      return const SyncRunResult(
        SyncRunStatus.noPeers,
        message: 'Синхронизация недоступна в Web-клиенте',
      );
    }

    final activity = _ref.read(syncActivityProvider.notifier);
    final transferReporter = _ref.read(syncTransferReporterProvider);
    lanSyncTransferProgress.onProgress = transferReporter.onProgress;

    try {
      final coordinator = await _ref.read(lanSyncCoordinatorProvider.future);
      final transport = _ref.read(syncTransportProvider);
      final lan = transport.lanAccess;
      if (lan == null) {
        return const SyncRunResult(
          SyncRunStatus.failed,
          message: 'LAN transport недоступен',
        );
      }

      final trusted = await _ref.read(trustedDevicesProvider.future);
      final peers = excludePeerId == null
          ? trusted
          : trusted.where((p) => p.peerId != excludePeerId).toList();
      if (peers.isEmpty) {
        return const SyncRunResult(
          SyncRunStatus.noPeers,
          message: 'Нет доверенных устройств',
        );
      }

      activity.begin(totalPeers: peers.length);
      final identity = await _ref.read(localIdentityProvider.future);
      final repo = await _ref.read(noteRepositoryProvider.future);
      await repo.purgeMisfiledRemoteOutbox(
        localAuthorLabels: localAuthorLabels(identity.displayName),
      );

      final result = await coordinator.syncTrustedPeers(
        transport: lan,
        repository: repo,
        trusted: trusted,
        excludePeerId: excludePeerId,
        localPeerId: identity.peerId,
        propagateCascade: propagateCascade,
        onPeerProgress: ({required peer, required completed, required total}) {
          activity.setPeer(
            label: 'Синхронизация с ${peer.name}',
            completedPeers: completed,
            totalPeers: total,
          );
        },
      );

      _invalidateSyncState();

      return SyncRunResult(
        switch (result.status) {
          LanSyncRunStatus.noPeers => SyncRunStatus.noPeers,
          LanSyncRunStatus.completed => SyncRunStatus.completed,
          LanSyncRunStatus.failed => SyncRunStatus.failed,
        },
        noteCount: result.noteCount,
        message: result.message,
      );
    } finally {
      lanSyncTransferProgress.onProgress = null;
      activity.finish();
    }
  }

  void _invalidateSyncState() {
    _ref.invalidate(outboxCountProvider);
    _ref.invalidate(pendingSyncNoteIdsProvider);
    _ref.invalidate(outboxFailedCountProvider);
    _ref.invalidate(notesListProvider);
    _ref.invalidate(trustedDevicesProvider);
  }
}
