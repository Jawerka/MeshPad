import 'dart:convert';

import 'package:meshpad_core/meshpad_core.dart';

/// UDP announce payload for LAN discovery (interim until libp2p/mDNS).
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
