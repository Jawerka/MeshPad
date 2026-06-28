import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/local_device_identity.dart';
import 'meshpad_paths.dart';
import 'peer_auth_token_store.dart';

/// Moves `auth_token` from `trusted/*.json` into [tokenStore] (PLAN §11.2.2).
Future<int> migrateEmbeddedAuthTokensToStore({
  required MeshPadPaths paths,
  required PeerAuthTokenStore tokenStore,
}) async {
  if (tokenStore is EmbeddedPeerAuthTokenStore) return 0;

  final trustedDir = Directory(p.join(paths.devicesRoot, 'trusted'));
  if (!await trustedDir.exists()) return 0;

  var migrated = 0;
  await for (final entity in trustedDir.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;

    final json =
        jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
    final token = json['auth_token'] as String?;
    if (token == null || token.isEmpty) continue;

    final record = TrustedDeviceRecord.fromJson(json);
    await tokenStore.write(record.peerId, token);

    json.remove('auth_token');
    await entity.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
    migrated++;
  }

  return migrated;
}
