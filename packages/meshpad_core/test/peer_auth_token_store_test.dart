import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_tokens_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('external store keeps auth_token out of trusted JSON', () async {
    final paths = MeshPadPaths(tempDir.path);
    final tokens = FilePeerAuthTokenStore(paths: paths);
    final store = DeviceIdentityStore(paths: paths, authTokens: tokens);

    await store.trustDevice(
      peerId: 'peer-1',
      name: 'Phone',
      authToken: 'secret-token',
    );

    expect(await store.authTokenForPeer('peer-1'), 'secret-token');

    final trustedFile = File(paths.trustedDeviceFile('peer-1'));
    final json =
        jsonDecode(await trustedFile.readAsString()) as Map<String, dynamic>;
    expect(json.containsKey('auth_token'), isFalse);
    expect(await tokens.read('peer-1'), 'secret-token');
  });

  test('migrateEmbeddedAuthTokensToStore moves token off disk JSON', () async {
    final paths = MeshPadPaths(tempDir.path);
    final legacy = DeviceIdentityStore(paths: paths);
    await legacy.trustDevice(
      peerId: 'peer-1',
      name: 'Laptop',
      authToken: 'legacy-secret',
    );

    final tokens = FilePeerAuthTokenStore(paths: paths);
    final migrated = await migrateEmbeddedAuthTokensToStore(
      paths: paths,
      tokenStore: tokens,
    );
    expect(migrated, 1);

    final json = jsonDecode(
      await File(paths.trustedDeviceFile('peer-1')).readAsString(),
    ) as Map<String, dynamic>;
    expect(json.containsKey('auth_token'), isFalse);
    expect(await tokens.read('peer-1'), 'legacy-secret');

    final store = DeviceIdentityStore(paths: paths, authTokens: tokens);
    expect(await store.authTokenForPeer('peer-1'), 'legacy-secret');
  });

  test('revokeTrust removes external token file', () async {
    final paths = MeshPadPaths(tempDir.path);
    final tokens = FilePeerAuthTokenStore(paths: paths);
    final store = DeviceIdentityStore(paths: paths, authTokens: tokens);
    await store.trustDevice(peerId: 'peer-1', name: 'X', authToken: 't');
    await store.revokeTrust('peer-1');
    expect(await tokens.read('peer-1'), isNull);
  });

  test('missing external token yields null authTokenForPeer', () async {
    final paths = MeshPadPaths(tempDir.path);
    final tokens = FilePeerAuthTokenStore(paths: paths);
    final store = DeviceIdentityStore(paths: paths, authTokens: tokens);
    await store.trustDevice(
      peerId: 'peer-1',
      name: 'Phone',
      authToken: 'secret-token',
    );
    await tokens.delete('peer-1');
    expect(await store.authTokenForPeer('peer-1'), isNull);
    expect(await File(paths.trustedDeviceFile('peer-1')).exists(), isTrue);
  });
}
