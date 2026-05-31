import 'dart:convert';

import 'package:mdns_dart/mdns_dart.dart';

import 'package:meshpad_core/meshpad_core.dart';

import 'lan_broadcast.dart';

/// DNS-SD service type for MeshPad LAN sync (PLAN §5.1).
const meshpadMdnsServiceType = '_meshpad._tcp';

/// UDP announce payload for LAN discovery (fallback + legacy peers).
class LanPeerAnnouncement {
  const LanPeerAnnouncement({
    required this.peerId,
    required this.displayName,
    required this.host,
    required this.httpPort,
  });

  static const protocolVersion = 1;

  final String peerId;
  final String displayName;
  final String host;
  final int httpPort;

  Map<String, dynamic> toJson() => {
        'v': protocolVersion,
        'type': 'meshpad_announce',
        'peer_id': peerId,
        'display_name': displayName,
        'host': host,
        'http_port': httpPort,
      };

  factory LanPeerAnnouncement.fromJson(Map<String, dynamic> json) {
    return LanPeerAnnouncement(
      peerId: json['peer_id'] as String,
      displayName: json['display_name'] as String? ?? 'MeshPad',
      host: json['host'] as String,
      httpPort: json['http_port'] as int,
    );
  }

  static LanPeerAnnouncement? tryParseDatagram(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['type'] != 'meshpad_announce') return null;
      if (json['v'] != protocolVersion) return null;
      return LanPeerAnnouncement.fromJson(json);
    } on Object {
      return null;
    }
  }

  List<int> toDatagram() => utf8.encode(jsonEncode(toJson()));

  static LanPeerAnnouncement? tryParseMdnsService(ServiceEntry entry) {
    if (!entry.isComplete) return null;

    final fields = parseMdnsTxtFields(entry.infoFields);
    final version = int.tryParse(fields['v'] ?? '') ?? 0;
    if (version != protocolVersion) return null;

    final peerId = fields['peer_id'];
    if (peerId == null || entry.port == 0) return null;

    final host = _preferredMdnsHost(entry);
    if (host == null) return null;

    return LanPeerAnnouncement(
      peerId: peerId,
      displayName: _decodeMdnsDisplayName(fields['display_name'] ?? entry.name),
      host: host,
      httpPort: entry.port,
    );
  }
}

String? _preferredMdnsHost(ServiceEntry entry) {
  final addresses = entry.addrsV4;
  if (addresses == null || addresses.isEmpty) {
    return entry.primaryAddress?.address;
  }
  var best = addresses.first.address;
  for (final address in addresses.skip(1)) {
    best = preferredLanHost(best, address.address);
  }
  return best;
}

String _decodeMdnsDisplayName(String raw) {
  if (raw.isEmpty) return 'MeshPad';
  try {
    return Uri.decodeComponent(raw.replaceAll('+', ' '));
  } on Object {
    return raw;
  }
}

Map<String, String> parseMdnsTxtFields(List<String> fields) {
  final map = <String, String>{};
  for (final field in fields) {
    final separator = field.indexOf('=');
    if (separator <= 0) continue;
    map[field.substring(0, separator)] = field.substring(separator + 1);
  }
  return map;
}

class LanPeerEndpoint {
  const LanPeerEndpoint({
    required this.peerId,
    required this.displayName,
    required this.host,
    required this.httpPort,
  });

  final String peerId;
  final String displayName;
  final String host;
  final int httpPort;

  factory LanPeerEndpoint.fromAnnouncement(LanPeerAnnouncement announcement) {
    return LanPeerEndpoint(
      peerId: announcement.peerId,
      displayName: announcement.displayName,
      host: announcement.host,
      httpPort: announcement.httpPort,
    );
  }

  Uri uriFor(String path) => Uri(
        scheme: 'http',
        host: host,
        port: httpPort,
        path: path,
      );
}

String noteApplyResultWire(NoteApplyResult result) => switch (result) {
      NoteApplyResult.applied => 'applied',
      NoteApplyResult.skippedLocalNewer => 'skipped_local_newer',
      NoteApplyResult.unchanged => 'unchanged',
    };

NoteApplyResult noteApplyResultFromWire(String value) => switch (value) {
      'applied' => NoteApplyResult.applied,
      'skipped_local_newer' => NoteApplyResult.skippedLocalNewer,
      _ => NoteApplyResult.unchanged,
    };
