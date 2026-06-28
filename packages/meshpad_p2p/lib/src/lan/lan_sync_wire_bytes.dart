/// Bytes transferred during the current LAN sync session (PLAN §11, task 1.6).
abstract final class LanSyncWireBytes {
  static var sessionTotal = 0;

  static void beginSession() => sessionTotal = 0;

  static void add(int bytes) {
    if (bytes > 0) sessionTotal += bytes;
  }
}
