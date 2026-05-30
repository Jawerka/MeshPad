/// Trusted or discovered peer device.
class Device {
  const Device({
    required this.peerId,
    required this.name,
    this.icon = 'device',
    this.trusted = false,
    this.lastSeenAt,
    this.lanHost,
    this.lanHttpPort,
  });

  final String peerId;
  final String name;
  final String icon;
  final bool trusted;
  final DateTime? lastSeenAt;
  final String? lanHost;
  final int? lanHttpPort;

  bool get hasLanEndpoint => lanHost != null && lanHttpPort != null;

  Device copyWith({
    String? name,
    String? icon,
    bool? trusted,
    DateTime? lastSeenAt,
    String? lanHost,
    int? lanHttpPort,
  }) {
    return Device(
      peerId: peerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      trusted: trusted ?? this.trusted,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lanHost: lanHost ?? this.lanHost,
      lanHttpPort: lanHttpPort ?? this.lanHttpPort,
    );
  }
}
