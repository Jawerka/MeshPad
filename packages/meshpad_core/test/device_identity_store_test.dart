import 'dart:convert';
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

  test('loadOrCreateIdentity provisions Ed25519 signing keys', () async {
    final paths = MeshPadPaths(tempDir.path);
    final signingKeys = MemoryDeviceSigningKeyStore();
    final store = DeviceIdentityStore(
      paths: paths,
      signingKeys: signingKeys,
    );

    final identity = await store.loadOrCreateIdentity(defaultDisplayName: 'PC');
    expect(identity.signingPublicKey, isNotNull);
    expect(identity.signingKeyAlgorithm, deviceSigningAlgorithmEd25519);

    final privateKey = await signingKeys.readPrivateKey();
    expect(privateKey, isNotNull);

    final file = File(paths.localIdentityFile);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['signing_public_key'], identity.signingPublicKey);
    expect(json.containsKey('signing_private_key'), isFalse);

    final reloaded = await store.loadOrCreateIdentity();
    expect(reloaded.signingPublicKey, identity.signingPublicKey);
  });

  test('lost signing private key rotates and marks re-pair needed', () async {
    final paths = MeshPadPaths(tempDir.path);
    final signingKeys = MemoryDeviceSigningKeyStore();
    final store = DeviceIdentityStore(
      paths: paths,
      signingKeys: signingKeys,
    );

    final first = await store.loadOrCreateIdentity(defaultDisplayName: 'PC');
    final oldPublic = first.signingPublicKey;
    expect(oldPublic, isNotNull);

    await signingKeys.delete();
    expect(await store.signingKeyNeedsRePair(), isFalse);

    final second = await store.loadOrCreateIdentity();
    expect(second.signingPublicKey, isNot(oldPublic));
    expect(await store.signingKeyNeedsRePair(), isTrue);

    await store.trustDevice(peerId: 'peer-1', name: 'Phone', authToken: 't');
    expect(await store.signingKeyNeedsRePair(), isFalse);
  });

  test('signing key reset marker clears only after all peers re-paired',
      () async {
    final paths = MeshPadPaths(tempDir.path);
    final signingKeys = MemoryDeviceSigningKeyStore();
    final store = DeviceIdentityStore(
      paths: paths,
      signingKeys: signingKeys,
    );

    await store.loadOrCreateIdentity(defaultDisplayName: 'PC');
    await store.trustDevice(peerId: 'peer-1', name: 'Phone A', authToken: 'a');
    await store.trustDevice(peerId: 'peer-2', name: 'Phone B', authToken: 'b');

    await signingKeys.delete();
    await store.loadOrCreateIdentity();
    expect(await store.signingKeyNeedsRePair(), isTrue);

    await store.trustDevice(peerId: 'peer-1', name: 'Phone A', authToken: 'a2');
    expect(await store.signingKeyNeedsRePair(), isTrue);

    await store.trustDevice(peerId: 'peer-2', name: 'Phone B', authToken: 'b2');
    expect(await store.signingKeyNeedsRePair(), isFalse);
  });

  test('persists and clears auth failure for trusted peer', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Phone', authToken: 't');

    await store.recordAuthFailure(
      peerId: 'peer-1',
      body: '{"unauthorized":"token"}',
    );

    var devices = await store.listTrustedDevices();
    expect(devices.single.authFailureBody, '{"unauthorized":"token"}');
    expect(devices.single.needsRePairing, isTrue);

    await store.clearAuthFailure('peer-1');
    devices = await store.listTrustedDevices();
    expect(devices.single.authFailureBody, isNull);
    expect(devices.single.needsRePairing, isFalse);
  });

  test('trust and list devices', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Phone');

    final devices = await store.listTrustedDevices();
    expect(devices.length, 1);
    expect(devices.first.name, 'Phone');
  });

  test('updates local and trusted device icons', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.loadOrCreateIdentity(defaultDisplayName: 'PC');
    await store.updateIcon('phone');

    final identity = await store.loadOrCreateIdentity();
    expect(identity.icon, 'phone');

    await store.trustDevice(peerId: 'peer-1', name: 'Phone', icon: 'device');
    await store.updateTrustedDeviceIcon(peerId: 'peer-1', icon: 'tablet');

    final devices = await store.listTrustedDevices();
    expect(devices.single.icon, 'tablet');
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

  test('rejects and clears loopback LAN endpoints', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(
      peerId: 'peer-1',
      name: 'Phone',
      lanHost: '192.168.1.10',
      lanHttpPort: 45838,
    );

    await store.updateLanEndpoint(
      peerId: 'peer-1',
      lanHost: '127.0.0.1',
      lanHttpPort: 45838,
    );
    final devices = await store.listTrustedDevices();
    expect(devices.single.lanHost, isNull);
  });

  test('persists auth token for trusted peer', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    const token = 'test-auth-token';
    await store.trustDevice(
      peerId: 'peer-1',
      name: 'Laptop',
      authToken: token,
    );

    expect(await store.authTokenForPeer('peer-1'), token);

    final file = File(MeshPadPaths(tempDir.path).trustedDeviceFile('peer-1'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['auth_token'], token);
  });

  test('generates auth token when not provided', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Phone');

    final token = await store.authTokenForPeer('peer-1');
    expect(token, isNotNull);
    expect(token!.length, greaterThan(10));
  });

  test('revokeAllTrusted removes every trusted peer file', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'A');
    await store.trustDevice(peerId: 'peer-2', name: 'B');

    final revoked = await store.revokeAllTrusted();

    expect(revoked, containsAll(['peer-1', 'peer-2']));
    expect(revoked.length, 2);
    expect(await store.listTrustedDevices(), isEmpty);
  });

  test('syncRemoteDisplayNameIfAllowed updates name from peer device',
      () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Old Phone');

    final updated = await store.syncRemoteDisplayNameIfAllowed(
      peerId: 'peer-1',
      remoteDisplayName: '  My Pixel  ',
    );

    expect(updated, isTrue);
    final devices = await store.listTrustedDevices();
    expect(devices.single.name, 'My Pixel');
  });

  test('syncRemoteDisplayNameIfAllowed skips locally customized name',
      () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Old Phone');
    await store.updateTrustedDeviceName(peerId: 'peer-1', name: 'Work phone');

    final updated = await store.syncRemoteDisplayNameIfAllowed(
      peerId: 'peer-1',
      remoteDisplayName: 'My Pixel',
    );

    expect(updated, isFalse);
    final devices = await store.listTrustedDevices();
    expect(devices.single.name, 'Work phone');

    final file = File(MeshPadPaths(tempDir.path).trustedDeviceFile('peer-1'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['name_customized'], isTrue);
  });

  test('trustDevice resets customized name on re-pairing', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-1', name: 'Phone');
    await store.updateTrustedDeviceName(peerId: 'peer-1', name: 'Alias');

    await store.trustDevice(peerId: 'peer-1', name: 'Phone again');

    final devices = await store.listTrustedDevices();
    expect(devices.single.name, 'Phone again');

    final file = File(MeshPadPaths(tempDir.path).trustedDeviceFile('peer-1'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json.containsKey('name_customized'), isFalse);
  });
}
