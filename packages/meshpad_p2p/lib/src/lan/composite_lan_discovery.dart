import 'lan_discovery.dart';
import 'lan_sync_codec.dart';
import '../meshpad_log.dart';
import 'mdns_lan_discovery.dart';
import 'udp_lan_discovery.dart';

/// Runs mDNS discovery (primary) and UDP broadcast (fallback for older peers).
class CompositeLanDiscovery implements LanDiscovery {
  CompositeLanDiscovery({
    MdnsLanDiscovery? mdns,
    UdpLanDiscovery? udp,
  })  : _mdns = mdns ?? MdnsLanDiscovery(),
        _udp = udp ?? UdpLanDiscovery();

  final MdnsLanDiscovery _mdns;
  final UdpLanDiscovery _udp;

  @override
  void Function(LanPeerAnnouncement announcement)? onPeerDiscovered;

  @override
  Future<void> start({
    required LanPeerAnnouncement Function() buildAnnouncement,
    String? bindHost,
  }) async {
    void forward(LanPeerAnnouncement announcement) {
      onPeerDiscovered?.call(announcement);
    }

    _mdns.onPeerDiscovered = forward;
    _udp.onPeerDiscovered = forward;

    await Future.wait([
      _mdns
          .start(buildAnnouncement: buildAnnouncement, bindHost: bindHost)
          .catchError((Object e) {
        MeshPadLog.warn('discovery', 'mDNS start failed: $e');
      }),
      _udp
          .start(buildAnnouncement: buildAnnouncement, bindHost: bindHost)
          .catchError((Object e) {
        MeshPadLog.warn('discovery', 'UDP start failed: $e');
      }),
    ]);
  }

  @override
  Future<void> stop() async {
    await Future.wait([
      _mdns.stop(),
      _udp.stop(),
    ]);
  }

  @override
  Future<void> refresh() async {
    await Future.wait([
      _mdns.refresh().catchError((Object e) {
        MeshPadLog.warn('discovery', 'mDNS refresh failed: $e');
      }),
      _udp.refresh().catchError((Object e) {
        MeshPadLog.warn('discovery', 'UDP refresh failed: $e');
      }),
    ]);
  }
}
