import 'dart:async';
import 'dart:io';

import 'lan_broadcast.dart';
import 'lan_discovery.dart';
import 'lan_socket_options.dart';
import 'lan_sync_codec.dart';
import '../meshpad_log.dart';

/// UDP broadcast discovery for MeshPad peers (legacy fallback).
class UdpLanDiscovery implements LanDiscovery {
  UdpLanDiscovery({
    this.discoveryPort = 45837,
    this.announceInterval = const Duration(seconds: 5),
  });

  static const globalBroadcastAddress = '255.255.255.255';

  final int discoveryPort;
  final Duration announceInterval;

  List<InternetAddress> _broadcastTargets = [
    InternetAddress(globalBroadcastAddress),
  ];

  @override
  void Function(LanPeerAnnouncement announcement)? onPeerDiscovered;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  void Function()? _sendAnnounce;

  @override
  Future<void> start({
    required LanPeerAnnouncement Function() buildAnnouncement,
    String? bindHost,
    bool advertise = true,
  }) async {
    if (_socket != null) return;

    _bindHost = bindHost;
    _advertise = advertise;
    final bindAddress = bindHost == null || bindHost.isEmpty
        ? InternetAddress.anyIPv4
        : InternetAddress(bindHost);
    _socket = await RawDatagramSocket.bind(
      bindAddress,
      discoveryPort,
      reuseAddress: true,
      reusePort: lanDatagramReusePort,
    );
    _socket!.broadcastEnabled = true;
    _broadcastTargets = await computeBroadcastTargets(lanHost: bindHost);
    MeshPadLog.discovery(
      'UDP discovery listening on ${bindAddress.address}:$discoveryPort; '
      'broadcast targets: ${_broadcastTargets.map((a) => a.address).join(", ")}'
      '${advertise ? '' : ' (browse-only)'}',
    );
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      var announcement = LanPeerAnnouncement.tryParseDatagram(datagram.data);
      if (announcement == null) return;
      if (!isUsableRemoteLanHost(announcement.host)) {
        final sourceHost = datagram.address.address;
        if (!isUsableRemoteLanHost(sourceHost)) {
          MeshPadLog.discovery(
            'UDP peer ${announcement.peerId} discarded '
            '(host=${announcement.host} source=$sourceHost)',
          );
          return;
        }
        announcement = LanPeerAnnouncement(
          peerId: announcement.peerId,
          displayName: announcement.displayName,
          host: sourceHost,
          httpPort: announcement.httpPort,
          tlsPort: announcement.tlsPort,
        );
      }
      MeshPadLog.discovery(
        'UDP peer ${announcement.peerId} at '
        '${announcement.host}:${announcement.httpPort}',
      );
      onPeerDiscovered?.call(announcement);
    });

    void sendAnnounce() {
      if (!_advertise) return;
      final announcement = buildAnnouncement();
      if (!isUsableRemoteLanHost(announcement.host)) {
        MeshPadLog.warn(
          'discovery',
          'UDP announce skipped: unusable host ${announcement.host}',
        );
        return;
      }
      final payload = announcement.toDatagram();
      MeshPadLog.discovery(
        'UDP announce ${announcement.displayName} '
        '(${announcement.peerId}) ${announcement.host}:${announcement.httpPort}',
      );
      for (final target in _broadcastTargets) {
        try {
          _socket?.send(payload, target, discoveryPort);
        } on SocketException catch (e) {
          MeshPadLog.warn('discovery', 'UDP announce send failed: $e');
        }
      }
    }

    _sendAnnounce = sendAnnounce;
    if (advertise) {
      sendAnnounce();
      _announceTimer = Timer.periodic(announceInterval, (_) => sendAnnounce());
    }
  }

  /// Exposed for tests (PLAN §11.4.1).
  static const refreshAttempts = 3;

  static const _refreshAttempts = refreshAttempts;

  String? _bindHost;

  bool _advertise = true;

  @override
  Future<void> refresh() async {
    _broadcastTargets = await computeBroadcastTargets(lanHost: _bindHost);
    if (!_advertise) return;
    for (var attempt = 0; attempt < _refreshAttempts; attempt++) {
      if (attempt > 0) {
        final delayMs = 300 * (1 << (attempt - 1));
        MeshPadLog.discovery(
          'UDP announce retry $attempt/${_refreshAttempts - 1} in ${delayMs}ms',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      _sendAnnounce?.call();
    }
  }

  @override
  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _sendAnnounce = null;
    _bindHost = null;
    _advertise = true;
    _socket?.close();
    _socket = null;
  }
}

String defaultLanHost() => InternetAddress.loopbackIPv4.address;

Future<String> detectLanHost() async {
  try {
    final candidates = await collectLanHostCandidates();
    final preferred = pickPreferredLanHost(candidates);
    if (preferred != null) {
      MeshPadLog.lan('detectLanHost chose $preferred (private LAN)');
      return preferred;
    }
    if (candidates.isNotEmpty) {
      MeshPadLog.lan('detectLanHost chose ${candidates.first} (fallback)');
      return candidates.first;
    }
  } on Object catch (e) {
    MeshPadLog.warn('lan', 'detectLanHost failed: $e');
  }
  MeshPadLog.lan('detectLanHost fallback to loopback');
  return defaultLanHost();
}
