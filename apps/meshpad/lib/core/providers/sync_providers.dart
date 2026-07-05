import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../platform/default_device_display_name.dart';
import '../storage/secure_device_signing_key_store.dart';
import '../storage/secure_peer_auth_token_store.dart';
import '../sync/local_author_labels.dart';
import 'notes_providers.dart';
import 'sync_activity_provider.dart';

final _outboxProcessor = OutboxProcessor();

var _syncInProgress = false;

final deviceStoreProvider = FutureProvider<DeviceIdentityStore>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw UnsupportedError('Device store unavailable on Web');
  }
  final dataDir = await ref.watch(dataDirProvider.future);
  final paths = MeshPadPaths(dataDir!);
  final tokenStore = SecurePeerAuthTokenStore();
  await migrateEmbeddedAuthTokensToStore(
    paths: paths,
    tokenStore: tokenStore,
  );
  return DeviceIdentityStore(
    paths: paths,
    authTokens: tokenStore,
    signingKeys: SecureDeviceSigningKeyStore(),
  );
});

final localIdentityProvider = FutureProvider<LocalDeviceIdentity>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw UnsupportedError('Device identity unavailable on Web');
  }
  final store = await ref.watch(deviceStoreProvider.future);
  return store.loadOrCreateIdentity(
      defaultDisplayName: defaultDeviceDisplayName());
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

final lanSyncCoordinatorProvider =
    FutureProvider<LanSyncCoordinator>((ref) async {
  final store = await ref.watch(deviceStoreProvider.future);
  return LanSyncCoordinator(deviceStore: store);
});

final syncTransportProvider = Provider<SyncTransport>((ref) {
  if (ref.watch(isWebClientProvider)) {
    final transport = FakeSyncTransport();
    ref.onDispose(transport.dispose);
    return transport;
  }

  final settings = ref.watch(appSettingsProvider).valueOrNull;
  final networkProfile = settings?.networkProfile ?? LanNetworkProfile.normal;

  final transportKind = SyncTransportKind.lan;

  final engineFuture = ref.watch(syncEngineProvider.future);
  final identityFuture = ref.watch(localIdentityProvider.future);
  final deviceStoreFuture = ref.watch(deviceStoreProvider.future);

  final transport = createSyncTransport(
    kind: transportKind,
    getEngine: () => engineFuture,
    getIdentity: () => identityFuture,
    getDeviceStore: () => deviceStoreFuture,
    onRemoteTrusted: (confirm) async {
      final store = await deviceStoreFuture;
      await trustDeviceFromPairingConfirm(
        store: store,
        confirm: confirm,
        onTrusted: () => ref.invalidate(trustedDevicesProvider),
      );
    },
    onCascadeSync: (cascade) async {
      await ref.read(syncControllerProvider).runSync(
            excludePeerIds: cascade.excludePeerIds,
            propagateCascade: cascade.hopLimit > 0,
            hopLimit: cascade.hopLimit,
          );
    },
    networkProfile: networkProfile,
  );
  ref.onDispose(transport.dispose);
  return transport;
});

final outboxFailedCountProvider = FutureProvider<int>((ref) async {
  if (ref.watch(isWebClientProvider)) return 0;
  final repo = await ref.watch(noteRepositoryProvider.future);
  return _outboxProcessor.failedCount(repo);
});

enum SyncRunStatus { noPeers, completed, partial, failed }

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
    List<String> excludePeerIds = const [],
    bool? propagateCascade,
    int? hopLimit,
  }) async {
    if (_ref.read(isWebClientProvider)) {
      return const SyncRunResult(
        SyncRunStatus.noPeers,
        message: 'Синхронизация недоступна в Web-клиенте',
      );
    }

    if (_syncInProgress) {
      return const SyncRunResult(
        SyncRunStatus.failed,
        message: 'Синхронизация уже выполняется',
      );
    }

    _syncInProgress = true;
    final activity = _ref.read(syncActivityProvider.notifier);
    final transferReporter = _ref.read(syncTransferReporterProvider);
    lanSyncTransferProgress.onProgress = transferReporter.onProgress;

    try {
      final coordinator = await _ref.read(lanSyncCoordinatorProvider.future);
      final transport = _ref.read(syncTransportProvider);

      final trusted = await _ref.read(trustedDevicesProvider.future);
      final excluded = {
        ...excludePeerIds,
        if (excludePeerId != null) excludePeerId,
      };
      final peers = trusted
          .where((peer) => !excluded.contains(peer.peerId))
          .toList();
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

      final settings = await _ref.read(appSettingsProvider.future);
      final profile =
          LanNetworkProfileSettings.forProfile(settings.networkProfile);
      final cascade = propagateCascade ?? profile.propagateCascade;
      final effectiveHopLimit = hopLimit ?? profile.cascadeHopLimit;

      final lan = transport.lanAccess;
      if (lan == null) {
        return const SyncRunResult(
          SyncRunStatus.failed,
          message: 'LAN transport недоступен',
        );
      }

      final result = await coordinator.syncTrustedPeers(
        transport: lan,
        repository: repo,
        trusted: trusted,
        excludePeerIds: excluded.toList(growable: false),
        localPeerId: identity.peerId,
        propagateCascade: cascade,
        hopLimit: effectiveHopLimit,
        maxConcurrentPeers: profile.maxConcurrentPeers,
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
          LanSyncRunStatus.partial => SyncRunStatus.partial,
          LanSyncRunStatus.failed => SyncRunStatus.failed,
        },
        noteCount: result.noteCount,
        message: result.message,
      );
    } catch (e, st) {
      MeshPadLog.warn('sync', 'runSync failed: $e');
      MeshPadLog.warn('sync', '$st');
      final message =
          e is MeshPadException ? e.message : meshPadExceptionUserMessage(e);
      return SyncRunResult(SyncRunStatus.failed, message: message);
    } finally {
      lanSyncTransferProgress.onProgress = null;
      activity.finish();
      _syncInProgress = false;
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

/// Exposed for unit tests.
bool get isSyncControllerBusy => _syncInProgress;

/// Exposed for unit tests.
void resetSyncControllerBusyForTest() => _syncInProgress = false;

/// Exposed for unit tests.
void setSyncControllerBusyForTest(bool value) => _syncInProgress = value;
