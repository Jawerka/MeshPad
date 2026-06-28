import 'dart:io';

/// Default friendly name for a new device before the user renames it.
String defaultDeviceDisplayName() {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isLinux) return 'Linux';
  return 'MeshPad';
}
