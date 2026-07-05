/// LAN discovery/sync aggressiveness preset.
enum LanNetworkProfile {
  normal,
  gentle,
}

/// Timing and behavior for a [LanNetworkProfile].
class LanNetworkProfileSettings {
  const LanNetworkProfileSettings({
    required this.mdnsBrowseInterval,
    required this.mdnsBrowseTimeout,
    required this.udpAnnounceInterval,
    required this.propagateCascade,
    required this.idleDiscoveryEnabled,
    required this.defaultAutoSyncIntervalMinutes,
    required this.discoveryPeerTtl,
    required this.cascadeHopLimit,
    required this.backgroundCascadeHopLimit,
    required this.maxConcurrentPeers,
  });

  final Duration mdnsBrowseInterval;
  final Duration mdnsBrowseTimeout;
  final Duration udpAnnounceInterval;
  final bool propagateCascade;
  final bool idleDiscoveryEnabled;
  final int defaultAutoSyncIntervalMinutes;
  final Duration discoveryPeerTtl;
  final int cascadeHopLimit;
  final int backgroundCascadeHopLimit;
  final int maxConcurrentPeers;

  static LanNetworkProfileSettings forProfile(LanNetworkProfile profile) {
    return switch (profile) {
      LanNetworkProfile.normal => const LanNetworkProfileSettings(
          mdnsBrowseInterval: Duration(seconds: 10),
          mdnsBrowseTimeout: Duration(seconds: 4),
          udpAnnounceInterval: Duration(seconds: 5),
          propagateCascade: true,
          idleDiscoveryEnabled: false,
          defaultAutoSyncIntervalMinutes: 15,
          discoveryPeerTtl: Duration(minutes: 15),
          cascadeHopLimit: 8,
          backgroundCascadeHopLimit: 3,
          maxConcurrentPeers: 2,
        ),
      LanNetworkProfile.gentle => const LanNetworkProfileSettings(
          mdnsBrowseInterval: Duration(seconds: 60),
          mdnsBrowseTimeout: Duration(seconds: 4),
          udpAnnounceInterval: Duration(seconds: 30),
          propagateCascade: false,
          idleDiscoveryEnabled: true,
          defaultAutoSyncIntervalMinutes: 30,
          discoveryPeerTtl: Duration(minutes: 30),
          cascadeHopLimit: 1,
          backgroundCascadeHopLimit: 1,
          maxConcurrentPeers: 1,
        ),
    };
  }
}

LanNetworkProfile lanNetworkProfileFromWire(String? raw) {
  return switch (raw) {
    'gentle' => LanNetworkProfile.gentle,
    _ => LanNetworkProfile.normal,
  };
}

String lanNetworkProfileToWire(LanNetworkProfile profile) => switch (profile) {
      LanNetworkProfile.gentle => 'gentle',
      LanNetworkProfile.normal => 'normal',
    };
