import 'dart:io';

import 'package:mdns_dart/mdns_dart.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('tryParseMdnsService reads TXT records', () {
    final entry = ServiceEntry(
      name: 'MeshPad-abc12345',
      host: 'host.local',
      addrsV4: [InternetAddress('192.168.1.20')],
      port: 45838,
      infoFields: [
        'peer_id=550e8400-e29b-41d4-a716-446655440000',
        'display_name=Office%20PC',
        'v=1',
      ],
    )..markHasTXT();

    final parsed = LanPeerAnnouncement.tryParseMdnsService(entry);

    expect(parsed, isNotNull);
    expect(parsed!.peerId, '550e8400-e29b-41d4-a716-446655440000');
    expect(parsed.displayName, 'Office PC');
    expect(parsed.host, '192.168.1.20');
    expect(parsed.httpPort, 45838);
  });

  test('tryParseMdnsService rejects unsupported protocol version', () {
    final entry = ServiceEntry(
      name: 'MeshPad-old',
      addrsV4: [InternetAddress('10.0.0.2')],
      port: 8080,
      infoFields: ['peer_id=x', 'v=99'],
    )..markHasTXT();

    expect(LanPeerAnnouncement.tryParseMdnsService(entry), isNull);
  });
}
