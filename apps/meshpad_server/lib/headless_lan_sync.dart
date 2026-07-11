import 'dart:async';
import 'dart:convert';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'note_change_hub.dart';

/// Background LAN P2P sync for headless server (ARCHITECTURE.md).
class HeadlessLanSyncService {
  HeadlessLanSyncService({
    required this.repository,
    required this.deviceStore,
    required this.engine,
    required this.identity,
    this.syncInterval = const Duration(minutes: 15),
    this.changeHub,
    this.networkProfile = LanNetworkProfile.normal,
    this.onSyncCompleted,
    this.onSyncStarted,
    this.onPairingConfirmed,
  });

  final NoteRepository repository;
  final DeviceIdentityStore deviceStore;
  final SyncEngine engine;
  final LocalDeviceIdentity identity;
  final Duration syncInterval;
  final NoteChangeHub? changeHub;
  final LanNetworkProfile networkProfile;
  final void Function(LanSyncRunResult result)? onSyncCompleted;
  final void Function()? onSyncStarted;
  final void Function(String initiatorPeerId)? onPairingConfirmed;

  LanSyncTransport? _transport;
  Timer? _timer;
  Timer? _startupTimer;
  StreamSubscription<SyncTransportEvent>? _eventsSub;
  var _syncInProgress = false;
  var _started = false;

  bool get isSyncInProgress => _syncInProgress;

  LanNetworkProfileSettings get _profileSettings =>
      LanNetworkProfileSettings.forProfile(networkProfile);

  LanSyncTransport get transport {
    return _transport ??= LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => deviceStore,
      networkProfile: networkProfile,
      onRemoteTrusted: (confirm) => trustDeviceFromPairingConfirm(
        store: deviceStore,
        confirm: confirm,
      ),
      onCascadeSync: (cascade) => runSync(
        excludePeerIds: cascade.excludePeerIds,
        propagateCascade: cascade.hopLimit > 0,
        hopLimit: cascade.hopLimit,
      ),
    );
  }

  LanSyncCoordinator get coordinator => LanSyncCoordinator(
        deviceStore: deviceStore,
      );

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await transport.start();
    _eventsSub = transport.events.listen(
      (event) async {
        await _onTransportEvent(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        MeshPadLog.warn('sync', 'headless transport events error: $error');
        MeshPadLog.warn('sync', '$stackTrace');
      },
    );

    _timer = Timer.periodic(syncInterval, (_) => unawaited(runSync()));
    _startupTimer =
        Timer(const Duration(seconds: 8), () => unawaited(runSync()));
  }

  Future<void> _onTransportEvent(SyncTransportEvent event) async {
    if (event is PeerDiscovered) {
      await coordinator.rememberDiscoveredTrustedEndpoint(
        transport: transport,
        peerId: event.peerId,
      );
      final trusted = await deviceStore.listTrustedDevices();
      if (trusted.any((device) => device.peerId == event.peerId)) {
        unawaited(runSync());
      }
      return;
    }

    if (event is PairingConfirmedRemotely) {
      MeshPadLog.pairing(
        'hub trusted guest ${event.initiatorPeerId} — syncing',
      );
      onPairingConfirmed?.call(event.initiatorPeerId);
      unawaited(runSync());
    }
  }

  Future<LanSyncRunResult> runSync({
    String? excludePeerId,
    List<String> excludePeerIds = const [],
    bool? propagateCascade,
    int? hopLimit,
  }) async {
    if (_syncInProgress) {
      return const LanSyncRunResult(
        LanSyncRunStatus.failed,
        message: 'Синхронизация уже выполняется',
      );
    }

    _syncInProgress = true;
    onSyncStarted?.call();
    try {
      await repository.purgeExpiredTrash();

      final trusted = await deviceStore.listTrustedDevices();
      final excluded = {
        ...excludePeerIds,
        if (excludePeerId != null) excludePeerId,
      }.toList(growable: false);

      final signingKey = await deviceStore.readSigningPrivateKey();
      final dataDir = repository.paths.root;
      final tlsRoot = MeshPadPaths(dataDir).tlsRoot;

      final result = await runForegroundLanSync(
        dataDir: dataDir,
        defaultAuthor: identity.displayName,
        networkProfile: networkProfile,
        localPeerId: identity.peerId,
        deviceStore: deviceStore,
        transport: transport,
        trustedPeers: trusted,
        excludePeerIds: excluded,
        propagateCascade: propagateCascade ?? _profileSettings.propagateCascade,
        hopLimit: hopLimit ?? _profileSettings.cascadeHopLimit,
        signingKeyBase64: signingKey == null ? null : base64Encode(signingKey),
        tlsRootPath: tlsRoot,
      );

      if (result.status == LanSyncRunStatus.completed && result.noteCount > 0) {
        changeHub?.feedChanged();
      }
      if (result.status == LanSyncRunStatus.partial && result.noteCount > 0) {
        changeHub?.feedChanged();
      }
      onSyncCompleted?.call(result);
      return result;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _startupTimer?.cancel();
    _startupTimer = null;
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
