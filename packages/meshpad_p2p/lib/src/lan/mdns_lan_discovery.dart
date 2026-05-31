import 'dart:async';
import 'dart:io';

import 'package:mdns_dart/mdns_dart.dart';

import 'lan_discovery.dart';
import 'lan_sync_codec.dart';
import '../meshpad_log.dart';
import 'udp_lan_discovery.dart';

/// mDNS/Bonjour discovery and advertisement for MeshPad peers (PLAN §5.1).
class MdnsLanDiscovery implements LanDiscovery {
  MdnsLanDiscovery({
    this.browseInterval = const Duration(seconds: 10),
    this.browseTimeout = const Duration(seconds: 4),
  });

  final Duration browseInterval;
  final Duration browseTimeout;

  MDNSServer? _server;
  Timer? _browseTimer;
  Future<void> Function()? _browse;
  Future<void>? _browseInFlight;

  @override
  void Function(LanPeerAnnouncement announcement)? onPeerDiscovered;

  @override
  Future<void> start({
    required LanPeerAnnouncement Function() buildAnnouncement,
    bool advertise = true,
  }) async {
    if (_server != null || _browse != null) return;

    if (advertise) {
      final announcement = buildAnnouncement();
      final ips = await _resolveIps(announcement.host);
      MeshPadLog.discovery(
        'mDNS advertise ${announcement.peerId} on $ips:${announcement.httpPort}',
      );
      final service = await MDNSService.create(
        instance: mdnsInstanceName(announcement.peerId),
        service: meshpadMdnsServiceType,
        port: announcement.httpPort,
        ips: ips,
        txt: txtRecordsFor(announcement),
      );

      _server = MDNSServer(
        MDNSServerConfig(zone: service, reuseAddress: true),
      );
      await _server!.start();
    } else {
      MeshPadLog.discovery('mDNS browse-only (no advertise)');
    }

    Future<void> browse() async {
      if (_browseInFlight != null) {
        return _browseInFlight!;
      }
      final run = _browseOnce();
      _browseInFlight = run;
      try {
        await run;
      } finally {
        if (identical(_browseInFlight, run)) {
          _browseInFlight = null;
        }
      }
    }

    _browse = browse;
    await browse();
    _browseTimer = Timer.periodic(browseInterval, (_) {
      unawaited(browse().catchError((Object e) {
        MeshPadLog.warn('discovery', 'mDNS browse failed: $e');
      }));
    });
  }

  Future<void> _browseOnce() async {
    try {
      final entries = await MDNSClient.discover(
        meshpadMdnsServiceType,
        timeout: browseTimeout,
        reuseAddress: true,
      );
      MeshPadLog.discovery('mDNS browse found ${entries.length} service(s)');
      for (final entry in entries) {
        final parsed = LanPeerAnnouncement.tryParseMdnsService(entry);
        if (parsed != null) {
          MeshPadLog.discovery(
            'mDNS peer ${parsed.peerId} at ${parsed.host}:${parsed.httpPort}',
          );
          onPeerDiscovered?.call(parsed);
        }
      }
    } on Object catch (e) {
      MeshPadLog.warn('discovery', 'mDNS browse failed: $e');
    }
  }

  @override
  Future<void> refresh() async {
    if (_browse != null) await _browse!();
  }

  @override
  Future<void> stop() async {
    _browseTimer?.cancel();
    _browseTimer = null;
    _browse = null;
    await _server?.stop();
    _server = null;
  }

  Future<List<InternetAddress>> _resolveIps(String host) async {
    if (host != defaultLanHost()) {
      return [InternetAddress(host)];
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final ips = <InternetAddress>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) ips.add(address);
        }
      }
      if (ips.isNotEmpty) return ips;
    } on Object {
      // Fall back below.
    }
    return [InternetAddress(host)];
  }
}

String mdnsInstanceName(String peerId) {
  final compact = peerId.replaceAll('-', '');
  final suffix = compact.length > 8 ? compact.substring(0, 8) : compact;
  return 'MeshPad-$suffix';
}

List<String> txtRecordsFor(LanPeerAnnouncement announcement) => [
      'peer_id=${announcement.peerId}',
      'display_name=${Uri.encodeComponent(announcement.displayName)}',
      'v=${LanPeerAnnouncement.protocolVersion}',
      if (announcement.tlsPort != null) 'tls_port=${announcement.tlsPort}',
    ];
