import 'dart:async';
import 'dart:io';

import 'lan_sync_codec.dart';

/// UDP broadcast discovery for MeshPad peers on LAN (interim until mDNS/libp2p).
class UdpLanDiscovery {
  UdpLanDiscovery({
    this.discoveryPort = 45837,
    this.announceInterval = const Duration(seconds: 5),
  });

  static const broadcastAddress = '255.255.255.255';

  final int discoveryPort;
  final Duration announceInterval;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  void Function(LanPeerAnnouncement announcement)? onPeerDiscovered;

  Future<void> start({
    required LanPeerAnnouncement Function() buildAnnouncement,
  }) async {
    if (_socket != null) return;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      final announcement = LanPeerAnnouncement.tryParseDatagram(datagram.data);
      if (announcement == null) return;
      onPeerDiscovered?.call(announcement);
    });

    void sendAnnounce() {
      final announcement = buildAnnouncement();
      _socket?.send(
        announcement.toDatagram(),
        InternetAddress(broadcastAddress),
        discoveryPort,
      );
    }

    sendAnnounce();
    _announceTimer = Timer.periodic(announceInterval, (_) => sendAnnounce());
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _socket?.close();
    _socket = null;
  }
}

String defaultLanHost() => InternetAddress.loopbackIPv4.address;

Future<String> detectLanHost() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }
  } on Object {
    // Ignore and fall back below.
  }
  return defaultLanHost();
}
