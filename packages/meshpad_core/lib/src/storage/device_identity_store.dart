import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/local_device_identity.dart';
import 'meshpad_paths.dart';

/// File-system store for local identity and trusted peers.
class DeviceIdentityStore {
  DeviceIdentityStore({
    required MeshPadPaths paths,
    Uuid? uuid,
  })  : _paths = paths,
        _uuid = uuid ?? const Uuid();

  final MeshPadPaths _paths;
  final Uuid _uuid;

  Future<LocalDeviceIdentity> loadOrCreateIdentity({
    String defaultDisplayName = 'Это устройство',
  }) async {
    final file = File(_paths.localIdentityFile);
    if (await file.exists()) {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return LocalDeviceIdentity.fromJson(json);
    }

    final identity = LocalDeviceIdentity(
      peerId: _uuid.v4(),
      displayName: defaultDisplayName,
      createdAt: DateTime.now().toUtc(),
    );
    await _saveIdentity(identity);
    return identity;
  }

  Future<void> updateDisplayName(String displayName) async {
    final current = await loadOrCreateIdentity();
    await _saveIdentity(
      LocalDeviceIdentity(
        peerId: current.peerId,
        displayName: displayName,
        icon: current.icon,
        createdAt: current.createdAt,
      ),
    );
  }

  Future<void> updateIcon(String icon) async {
    final current = await loadOrCreateIdentity();
    await _saveIdentity(
      LocalDeviceIdentity(
        peerId: current.peerId,
        displayName: current.displayName,
        icon: icon,
        createdAt: current.createdAt,
      ),
    );
  }

  Future<void> updateTrustedDeviceName({
    required String peerId,
    required String name,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      TrustedDeviceRecord(
        peerId: record.peerId,
        name: name,
        icon: record.icon,
        trustedAt: record.trustedAt,
        lastSeenAt: record.lastSeenAt,
        lanHost: record.lanHost,
        lanHttpPort: record.lanHttpPort,
      ),
    );
  }

  Future<void> updateTrustedDeviceIcon({
    required String peerId,
    required String icon,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      TrustedDeviceRecord(
        peerId: record.peerId,
        name: record.name,
        icon: icon,
        trustedAt: record.trustedAt,
        lastSeenAt: record.lastSeenAt,
        lanHost: record.lanHost,
        lanHttpPort: record.lanHttpPort,
      ),
    );
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

  Future<void> trustDevice({
    required String peerId,
    required String name,
    String icon = 'device',
    String? lanHost,
    int? lanHttpPort,
  }) async {
    final trustedDir = Directory(p.join(_paths.devicesRoot, 'trusted'));
    await trustedDir.create(recursive: true);

    final record = TrustedDeviceRecord(
      peerId: peerId,
      name: name,
      icon: icon,
      trustedAt: DateTime.now().toUtc(),
      lastSeenAt: DateTime.now().toUtc(),
      lanHost: lanHost,
      lanHttpPort: lanHttpPort,
    );
    await _writeTrustedRecord(record);
  }

  Future<void> updateLanEndpoint({
    required String peerId,
    required String lanHost,
    required int lanHttpPort,
  }) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      TrustedDeviceRecord(
        peerId: record.peerId,
        name: record.name,
        icon: record.icon,
        trustedAt: record.trustedAt,
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
      TrustedDeviceRecord(
        peerId: record.peerId,
        name: record.name,
        icon: record.icon,
        trustedAt: record.trustedAt,
        lastSeenAt: record.lastSeenAt,
      ),
    );
  }

  Future<void> revokeTrust(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> markPeerSeen(String peerId) async {
    final record = await _loadTrustedRecord(peerId);
    if (record == null) return;

    await _writeTrustedRecord(
      TrustedDeviceRecord(
        peerId: record.peerId,
        name: record.name,
        icon: record.icon,
        trustedAt: record.trustedAt,
        lastSeenAt: DateTime.now().toUtc(),
        lanHost: record.lanHost,
        lanHttpPort: record.lanHttpPort,
      ),
    );
  }

  Future<TrustedDeviceRecord?> _loadTrustedRecord(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (!await file.exists()) return null;

    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return TrustedDeviceRecord.fromJson(json);
  }

  Future<void> _writeTrustedRecord(TrustedDeviceRecord record) async {
    await File(_paths.trustedDeviceFile(record.peerId)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }
}
