import 'lan_sync_codec.dart';

/// LAN peer discovery (mDNS + UDP fallback, PLAN §5.1).
abstract class LanDiscovery {
  void Function(LanPeerAnnouncement announcement)? onPeerDiscovered;

  Future<void> start({
    required LanPeerAnnouncement Function() buildAnnouncement,
    String? bindHost,
    bool advertise = true,
  });

  Future<void> stop();

  /// Re-run discovery (mDNS browse + UDP announce) to refresh peer endpoints.
  Future<void> refresh();
}
