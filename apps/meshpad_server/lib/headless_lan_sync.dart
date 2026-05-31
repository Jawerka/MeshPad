import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

/// Background LAN P2P sync for headless server (ARCHITECTURE.md).
class HeadlessLanSyncService {
  HeadlessLanSyncService({
    required this.repository,
    required this.deviceStore,
    required this.engine,
    required this.identity,
    this.syncInterval = const Duration(minutes: 15),
  });

  final NoteRepository repository;
  final DeviceIdentityStore deviceStore;
  final SyncEngine engine;
  final LocalDeviceIdentity identity;
  final Duration syncInterval;

  LanSyncTransport? _transport;
  Timer? _timer;
  StreamSubscription<SyncTransportEvent>? _eventsSub;
  var _syncInProgress = false;
  var _started = false;

  LanSyncTransport get transport {
    return _transport ??= LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      onRemoteTrusted: (confirm) async {
        final initiatorId = confirm.initiatorPeerId;
        final host = confirm.initiatorLanHost;
        final port = confirm.initiatorHttpPort;
        if (initiatorId == null || host == null || port == null) return;

        await deviceStore.trustDevice(
          peerId: initiatorId,
          name: confirm.initiatorDisplayName ?? 'Устройство',
          lanHost: host,
          lanHttpPort: port,
        );
      },
    );
  }

  LanSyncCoordinator get coordinator => LanSyncCoordinator(
        deviceStore: deviceStore,
      );

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await transport.start();
    _eventsSub = transport.events.listen((event) async {
      if (event is! PeerDiscovered) return;
      await coordinator.rememberDiscoveredTrustedEndpoint(
        transport: transport,
        peerId: event.peerId,
      );
    });

    _timer = Timer.periodic(syncInterval, (_) => unawaited(runSync()));
    unawaited(Future<void>.delayed(const Duration(seconds: 8), runSync));
  }

  Future<LanSyncRunResult> runSync() async {
    if (_syncInProgress) {
      return const LanSyncRunResult(
        LanSyncRunStatus.failed,
        message: 'Синхронизация уже выполняется',
      );
    }

    _syncInProgress = true;
    try {
      await repository.purgeExpiredTrash();
      return await coordinator.syncTrustedPeers(
        transport: transport,
        repository: repository,
      );
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await transport.stop();
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    transport.dispose();
  }
}
