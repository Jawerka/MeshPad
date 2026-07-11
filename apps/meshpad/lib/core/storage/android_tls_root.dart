import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// True when [dataDir] is on Android shared storage (SAF / Documents picker).
bool isAndroidSharedStorageDataDir(String dataDir) {
  if (!Platform.isAndroid) return false;
  final normalized = p.normalize(dataDir).replaceAll('\\', '/');
  return normalized.startsWith('/storage/emulated/') ||
      normalized.startsWith('/sdcard/') ||
      normalized.startsWith('/mnt/sdcard/');
}

/// TLS server certs must live in app-private storage on Android when notes use shared storage.
Future<String> resolveTlsRootForDataDir(String dataDir) async {
  if (isAndroidSharedStorageDataDir(dataDir)) {
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, 'meshpad_tls');
  }
  return MeshPadPaths(dataDir).tlsRoot;
}

Future<String> resolveTlsRoot(DeviceIdentityStore store) =>
    resolveTlsRootForDataDir(store.paths.root);
