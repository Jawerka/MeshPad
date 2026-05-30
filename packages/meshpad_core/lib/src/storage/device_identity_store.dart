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
  }) async {
    final trustedDir = Directory(p.join(_paths.devicesRoot, 'trusted'));
    await trustedDir.create(recursive: true);

    final record = TrustedDeviceRecord(
      peerId: peerId,
      name: name,
      icon: icon,
      trustedAt: DateTime.now().toUtc(),
      lastSeenAt: DateTime.now().toUtc(),
    );
    await File(_paths.trustedDeviceFile(peerId)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }

  Future<void> revokeTrust(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> markPeerSeen(String peerId) async {
    final file = File(_paths.trustedDeviceFile(peerId));
    if (!await file.exists()) return;

    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final record = TrustedDeviceRecord.fromJson(json);
    final updated = TrustedDeviceRecord(
      peerId: record.peerId,
      name: record.name,
      icon: record.icon,
      trustedAt: record.trustedAt,
      lastSeenAt: DateTime.now().toUtc(),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(updated.toJson()),
    );
  }
}
