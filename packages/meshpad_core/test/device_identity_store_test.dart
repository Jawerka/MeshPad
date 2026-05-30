import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_identity_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('creates and loads local identity', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    final a = await store.loadOrCreateIdentity(defaultDisplayName: 'Test');
    final b = await store.loadOrCreateIdentity(defaultDisplayName: 'Other');

    expect(a.peerId, b.peerId);
    expect(a.displayName, 'Test');
  });

  test('trust and list devices', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Phone');

    final devices = await store.listTrustedDevices();
    expect(devices.length, 1);
    expect(devices.first.name, 'Phone');
  });

  test('persists LAN endpoint for trusted peer', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(
      peerId: 'peer-1',
      name: 'Laptop',
      lanHost: '192.168.1.10',
      lanHttpPort: 45838,
    );

    var devices = await store.listTrustedDevices();
    expect(devices.first.lanHost, '192.168.1.10');
    expect(devices.first.lanHttpPort, 45838);

    await store.updateLanEndpoint(
      peerId: 'peer-1',
      lanHost: '192.168.1.11',
      lanHttpPort: 45839,
    );

    devices = await store.listTrustedDevices();
    expect(devices.first.lanHost, '192.168.1.11');
    expect(devices.first.lanHttpPort, 45839);
  });
}
