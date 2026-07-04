import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/local_device_identity.dart';
import '../security/device_signing.dart';
import '../sync/sync_auth.dart';
import 'device_signing_key_store.dart';
import 'meshpad_paths.dart';
import 'peer_auth_token_store.dart';

/// File-system store for local identity and trusted peers.
class DeviceIdentityStore {
  DeviceIdentityStore({
    required MeshPadPaths paths,
    PeerAuthTokenStore? authTokens,
    DeviceSigningKeyStore? signingKeys,
    Uuid? uuid,
  })  : _paths = paths,
        _authTokens = authTokens ?? const EmbeddedPeerAuthTokenStore(),
        _signingKeys = signingKeys ?? FileDeviceSigningKeyStore(paths),
        _uuid = uuid ?? const Uuid();

  final MeshPadPaths _paths;
  final PeerAuthTokenStore _authTokens;
  final DeviceSigningKeyStore _signingKeys;
  final Uuid _uuid;

  bool get usesExternalAuthTokens => _authTokens is! EmbeddedPeerAuthTokenStore;

  MeshPadPaths get paths => _paths;

  Future<LocalDeviceIdentity> loadOrCreateIdentity({
    String defaultDisplayName = 'Это устройство',
  }) async {
    final file = File(_paths.localIdentityFile);
    LocalDeviceIdentity identity;
    if (await file.exists()) {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      identity = LocalDeviceIdentity.fromJson(json);
    } else {
      identity = LocalDeviceIdentity(
        peerId: _uuid.v4(),
        displayName: defaultDisplayName,
        createdAt: DateTime.now().toUtc(),
      );
      await _saveIdentity(identity);
    }
    return _ensureSigningKeyPair(identity);
  }

  Future<LocalDeviceIdentity> _ensureSigningKeyPair(
    LocalDeviceIdentity identity,
  ) async {
    if (identity.signingPublicKey != null &&
        identity.signingPublicKey!.isNotEmpty) {
      final existing = await _signingKeys.readPrivateKey();
      if (existing != null) return identity;
    }

    final pair = await generateDeviceSigningKeyPair();
    await _signingKeys.writePrivateKey(pair.privateKeyBytes);
    final updated = LocalDeviceIdentity(
      peerId: identity.peerId,
      displayName: identity.displayName,
      icon: identity.icon,
      createdAt: identity.createdAt,
      signingPublicKey: pair.publicKeyBase64,
      signingKeyAlgorithm: pair.algorithm,
    );
    await _saveIdentity(updated);
    return updated;
  }

  Future<void> updateDisplayName(String displayName) async {
    final current = await loadOrCreateIdentity();
    await _saveIdentity(_copySigningFields(current, displayName: displayName));
  }

  Future<void> updateIcon(String icon) async {
    final current = await loadOrCreateIdentity();
    await _saveIdentity(_copySigningFields(current, icon: icon));
  }

  LocalDeviceIdentity _copySigningFields(
    LocalDeviceIdentity current, {
    String? displayName,
    String? icon,
  }) {
    return LocalDeviceIdentity(
      peerId: current.peerId,
      displayName: displayName ?? current.displayName,
      icon: icon ?? current.icon,
      createdAt: current.createdAt,
      signingPublicKey: current.signingPublicKey,
      signingKeyAlgorithm: current.signingKeyAlgorithm,
    );
  }

  Future<void> updateTrustedDeviceName({
    required String peerId,
    required String name,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      record.copyWith(name: name, nameCustomized: true),
    );
  }

  Future<void> updateTrustedDeviceIcon({
    required String peerId,
    required String icon,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(record.copyWith(icon: icon));
  }

  /// Applies the peer's self-assigned display name when the user has not
  /// renamed this device locally.
  ///
  /// Returns true when the stored name was updated.
  Future<bool> syncRemoteDisplayNameIfAllowed({
    required String peerId,
    required String remoteDisplayName,
  }) async {
    final trimmed = remoteDisplayName.trim();
    if (trimmed.isEmpty) return false;

    final record = await _loadTrustedRecord(peerId);
    if (record == null || record.nameCustomized) return false;
    if (record.name == trimmed) return false;

    await _writeTrustedRecord(record.copyWith(name: trimmed));
    return true;
  }

  Future<void> _saveIdentity(LocalDeviceIdentity identity) async {
    final dir = Directory(_paths.devicesRoot);
    await dir.create(recursive: true);
    await File(_paths.localIdentityFile).writeAsString(
      const JsonEncoder.withIndent('  ').convert(identity.toJson()),
    );
  }

  Future<List<Device>> listTrustedDevices() async {
    final trustedDir = Directory(p.join(_paths.devicesRoot, 'trusted'));
    if (!await trustedDir.exists()) return [];

    final devices = <Device>[];
    await for (final entity in trustedDir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      devices.add(TrustedDeviceRecord.fromJson(json).toDevice());
    }
    devices.sort((a, b) => a.name.compareTo(b.name));
    return devices;
  }

  Future<Uint8List?> readSigningPrivateKey() => _signingKeys.readPrivateKey();

  Future<void> trustDevice({
    required String peerId,
    required String name,
    String icon = 'device',
    String? lanHost,
    int? lanHttpPort,
    String? authToken,
    String? tlsCertSha256,
    String? signingPublicKey,
    String? signingKeyAlgorithm,
  }) async {
    final trustedDir = Directory(p.join(_paths.devicesRoot, 'trusted'));
    await trustedDir.create(recursive: true);

    final record = TrustedDeviceRecord(
      peerId: peerId,
      name: name,
      icon: icon,
      nameCustomized: false,
      trustedAt: DateTime.now().toUtc(),
      lastSeenAt: DateTime.now().toUtc(),
      lanHost: lanHost,
      lanHttpPort: lanHttpPort,
      authToken: authToken ?? generateSyncAuthToken(_uuid),
      tlsCertSha256: tlsCertSha256,
      signingPublicKey: signingPublicKey,
      signingKeyAlgorithm: signingKeyAlgorithm,
    );
    await _writeTrustedRecord(record);
  }

  Future<TrustedDeviceRecord?> trustedRecordFor(String peerId) =>
      _loadTrustedRecord(peerId);

  Future<String?> authTokenForPeer(String peerId) async {
    final record = await _loadTrustedRecord(peerId);
    return record?.authToken;
  }

  Future<void> updateLanEndpoint({
    required String peerId,
    required String lanHost,
    required int lanHttpPort,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      record.copyWith(
        lastSeenAt: DateTime.now().toUtc(),
        lanHost: lanHost,
        lanHttpPort: lanHttpPort,
      ),
    );
  }

  Future<void> clearLanEndpoint(String peerId) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      record.copyWith(clearLanHost: true, clearLanHttpPort: true),
    );
  }

  Future<void> revokeTrust(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (await file.exists()) {
      await file.delete();
    }
    await _authTokens.delete(peerId);
  }

  Future<List<String>> revokeAllTrusted() async {
    final trustedDir = Directory(p.join(_paths.devicesRoot, 'trusted'));
    if (!await trustedDir.exists()) return const [];

    final revoked = <String>[];
    await for (final entity in trustedDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final peerId = p.basenameWithoutExtension(entity.path);
      await entity.delete();
      await _authTokens.delete(peerId);
      revoked.add(peerId);
    }
    revoked.sort();
    return revoked;
  }

  Future<void> markPeerSeen(String peerId) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      record.copyWith(lastSeenAt: DateTime.now().toUtc()),
    );
  }

  Future<TrustedDeviceRecord?> _loadTrustedRecord(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (!await file.exists()) return null;

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    var record = TrustedDeviceRecord.fromJson(json);

    if (!usesExternalAuthTokens) return record;

    var token = await _authTokens.read(peerId);
    final embedded = json['auth_token'] as String?;
    if (token == null && embedded != null && embedded.isNotEmpty) {
      token = embedded;
      await _authTokens.write(peerId, token);
      record = record.copyWith(clearAuthToken: true);
      await _writeTrustedRecord(record);
    } else if (token != null) {
      record = record.copyWith(authToken: token);
    }
    return record;
  }

  Future<void> _writeTrustedRecord(TrustedDeviceRecord record) async {
    final file = File(_paths.trustedDeviceFile(record.peerId));
    if (usesExternalAuthTokens) {
      final token = record.authToken;
      if (token != null && token.isNotEmpty) {
        await _authTokens.write(record.peerId, token);
      }
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(record.toPublicJson()),
      );
      return;
    }

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }
}
