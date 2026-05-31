import 'dart:io';

/// Default friendly name for a new device before the user renames it.
String defaultDeviceDisplayName() {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iPhone';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'Mac';
  return 'MeshPad';
}
