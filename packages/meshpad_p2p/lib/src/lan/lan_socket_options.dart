import 'dart:io';

/// Whether [RawDatagramSocket.bind] may use `reusePort` on this platform.
///
/// Android logs `reusePort not supported` and discovery bind can fail.
bool get lanDatagramReusePort {
  if (Platform.isAndroid) return false;
  return Platform.isWindows || Platform.isLinux;
}
