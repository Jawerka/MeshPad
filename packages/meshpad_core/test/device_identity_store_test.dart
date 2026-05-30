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
}
