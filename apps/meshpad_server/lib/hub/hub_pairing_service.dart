import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../headless_lan_sync.dart';
import 'hub_sync_tracker.dart';

/// Keeps pairing offer + sync dashboard state for the hub web UI.
class HubPairingService {
  HubPairingService({
    required this.lanSync,
    required this.deviceStore,
    required this.repository,
    required this.identity,
    HubSyncTracker? syncTracker,
  }) : syncTracker = syncTracker ?? HubSyncTracker();

  final HeadlessLanSyncService lanSync;
  final DeviceIdentityStore deviceStore;
  final NoteRepository repository;
  final LocalDeviceIdentity identity;
  final HubSyncTracker syncTracker;

  PinPairingOffer? _offer;
  Timer? _refreshTimer;

  PinPairingOffer? get currentOffer => _offer;

  Future<void> start() async {
    await refreshPairing();
    _scheduleRefreshTimer();
  }

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await lanSync.transport.setPairingOffer(null);
    _offer = null;
  }

  Future<void> refreshPairing() async {
    final pin = generatePairingPin();
    final offer = createPairingOffer(
      peerId: identity.peerId,
      displayName: identity.displayName,
      pin: pin,
      signingPublicKey: identity.signingPublicKey,
      signingKeyAlgorithm: identity.signingKeyAlgorithm,
    );
    await lanSync.transport.setPairingOffer(offer);
    _offer = offer;
    _scheduleRefreshTimer();
  }

  void recordSyncStarted() => syncTracker.recordStarted();

  Future<void> recordSyncResult(LanSyncRunResult result) async {
    final peers = await deviceStore.listTrustedDevices();
    final names = {for (final p in peers) p.peerId: p.name};
    syncTracker.recordResult(result, peerNames: names);
  }

  Future<void> recordPairing({required String peerId}) async {
    final peers = await deviceStore.listTrustedDevices();
    final device = peers.where((p) => p.peerId == peerId).firstOrNull;
    syncTracker.recordPairing(
      deviceName: device?.name ?? peerId.substring(0, 8),
    );
    await refreshPairing();
  }

  Future<LanSyncRunResult> runSyncNow() => lanSync.runSync();

  Future<bool> revokeTrustedDevice(String peerId) async {
    final trusted = await deviceStore.listTrustedDevices();
    final device = trusted.where((p) => p.peerId == peerId).firstOrNull;
    if (device == null) return false;

    await deviceStore.revokeTrust(peerId);
    lanSync.transport.forgetPeer(peerId);
    syncTracker.recordDeviceRevoked(deviceName: device.name);
    await refreshPairing();
    return true;
  }

  Future<int> revokeAllTrustedDevices() async {
    final trusted = await deviceStore.listTrustedDevices();
    if (trusted.isEmpty) return 0;

    final revoked = await deviceStore.revokeAllTrusted();
    for (final peerId in revoked) {
      lanSync.transport.forgetPeer(peerId);
    }
    syncTracker.recordAllDevicesRevoked(revoked.length);
    await refreshPairing();
    return revoked.length;
  }

  Future<HubStatus> status({int? webPort}) async {
    await _ensureActivePairingOffer();

    final current = _offer;
    final transport = lanSync.transport;
    final host = transport.localLanHost;
    final httpPort = transport.localHttpPort;
    String? qrUri;
    if (current != null &&
        host != null &&
        httpPort != null &&
        !current.isExpired) {
      qrUri = PairingQrPayload(
        host: host,
        httpPort: httpPort,
        pin: current.pin,
        tlsPort: transport.localTlsPort,
      ).encode();
    }

    final trusted = await deviceStore.listTrustedDevices();
    final last = syncTracker.lastResult;
    final succeeded = last?.succeededPeerIds.toSet() ?? {};
    final failed = last?.failedPeerIds.toSet() ?? {};

    return HubStatus(
      displayName: identity.displayName,
      peerId: identity.peerId,
      pin: current?.isExpired == false ? current?.pin : null,
      qrUri: qrUri,
      lanHost: host,
      httpPort: httpPort,
      tlsPort: transport.localTlsPort,
      webPort: webPort,
      expiresAt: current?.expiresAt,
      trustedCount: trusted.length,
      noteCount: await repository.countActiveNotes(),
      pendingOutbox: await repository.pendingOutboxCount(),
      syncing: lanSync.isSyncInProgress || syncTracker.syncInProgress,
      lastSyncAt: syncTracker.lastSyncAt,
      lastSyncStatus: last?.status,
      lastSyncNoteCount: last?.noteCount ?? 0,
      lastSyncMessage: last?.message,
      trustedDevices: [
        for (final device in trusted)
          HubTrustedDevice(
            peerId: device.peerId,
            name: device.name,
            lanHost: device.lanHost,
            lanHttpPort: device.lanHttpPort,
            lastSeenAt: device.lastSeenAt,
            lastSyncOk: succeeded.contains(device.peerId)
                ? true
                : failed.contains(device.peerId)
                    ? false
                    : null,
          ),
      ],
      recentEvents: syncTracker.events.take(10).toList(),
    );
  }

  void _scheduleRefreshTimer() {
    _refreshTimer?.cancel();
    final offer = _offer;
    if (offer == null) return;
    final delay = offer.expiresAt.difference(DateTime.now().toUtc());
    final wait = delay.isNegative ? Duration.zero : delay;
    _refreshTimer = Timer(wait, () {
      unawaited(refreshPairing());
    });
  }

  /// Keeps [HubPairingService] and [LanPeerServer] offers in sync.
  Future<void> _ensureActivePairingOffer() async {
    final cached = _offer;
    if (cached != null && !cached.isExpired) {
      final live = lanSync.transport.currentPairingOffer;
      if (live != null &&
          live.pin == cached.pin &&
          live.peerId == cached.peerId) {
        return;
      }
    }
    await refreshPairing();
  }
}

class HubTrustedDevice {
  const HubTrustedDevice({
    required this.peerId,
    required this.name,
    required this.lanHost,
    required this.lanHttpPort,
    required this.lastSeenAt,
    required this.lastSyncOk,
  });

  final String peerId;
  final String name;
  final String? lanHost;
  final int? lanHttpPort;
  final DateTime? lastSeenAt;
  final bool? lastSyncOk;

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'name': name,
        if (lanHost != null) 'lan_host': lanHost,
        if (lanHttpPort != null) 'lan_http_port': lanHttpPort,
        if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
        if (lastSyncOk != null) 'last_sync_ok': lastSyncOk,
      };
}

class HubStatus {
  const HubStatus({
    required this.displayName,
    required this.peerId,
    required this.pin,
    required this.qrUri,
    required this.lanHost,
    required this.httpPort,
    required this.tlsPort,
    required this.webPort,
    required this.expiresAt,
    required this.trustedCount,
    required this.noteCount,
    required this.pendingOutbox,
    required this.syncing,
    required this.lastSyncAt,
    required this.lastSyncStatus,
    required this.lastSyncNoteCount,
    required this.lastSyncMessage,
    required this.trustedDevices,
    required this.recentEvents,
  });

  final String displayName;
  final String peerId;
  final String? pin;
  final String? qrUri;
  final String? lanHost;
  final int? httpPort;
  final int? tlsPort;
  final int? webPort;
  final DateTime? expiresAt;
  final int trustedCount;
  final int noteCount;
  final int pendingOutbox;
  final bool syncing;
  final DateTime? lastSyncAt;
  final LanSyncRunStatus? lastSyncStatus;
  final int lastSyncNoteCount;
  final String? lastSyncMessage;
  final List<HubTrustedDevice> trustedDevices;
  final List<HubSyncEvent> recentEvents;

  String get syncBadgeKind {
    if (syncing) return 'syncing';
    if (lastSyncStatus == null) return 'idle';
    return switch (lastSyncStatus!) {
      LanSyncRunStatus.completed => 'ok',
      LanSyncRunStatus.partial => 'partial',
      LanSyncRunStatus.failed => 'error',
      LanSyncRunStatus.noPeers => 'waiting',
    };
  }

  String get syncBadgeText {
    if (syncing) return 'Синхронизация…';
    if (lastSyncStatus == null) {
      return trustedCount == 0
          ? 'Подключите первое устройство'
          : 'Ожидание синхронизации';
    }
    return switch (lastSyncStatus!) {
      LanSyncRunStatus.completed => lastSyncNoteCount == 0
          ? 'Всё актуально'
          : 'Синхронизировано $lastSyncNoteCount зам.',
      LanSyncRunStatus.partial => 'Частичная синхронизация',
      LanSyncRunStatus.failed => lastSyncMessage ?? 'Ошибка',
      LanSyncRunStatus.noPeers => 'Нет устройств',
    };
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'peer_id': peerId,
        if (pin != null) 'pin': pin,
        if (qrUri != null) 'qr_uri': qrUri,
        if (lanHost != null) 'lan_host': lanHost,
        if (httpPort != null) 'http_port': httpPort,
        if (tlsPort != null) 'tls_port': tlsPort,
        if (webPort != null) 'web_port': webPort,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        'trusted_count': trustedCount,
        'note_count': noteCount,
        'pending_outbox': pendingOutbox,
        'syncing': syncing,
        'sync_badge_kind': syncBadgeKind,
        'sync_badge_text': syncBadgeText,
        if (lastSyncAt != null) 'last_sync_at': lastSyncAt!.toIso8601String(),
        if (lastSyncStatus != null) 'last_sync_status': lastSyncStatus!.name,
        'last_sync_note_count': lastSyncNoteCount,
        if (lastSyncMessage != null) 'last_sync_message': lastSyncMessage,
        'trusted_devices': trustedDevices.map((d) => d.toJson()).toList(),
        'recent_events': recentEvents.map((e) => e.toJson()).toList(),
      };
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
