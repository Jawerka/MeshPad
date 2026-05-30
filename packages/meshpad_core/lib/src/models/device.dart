/// Trusted or discovered peer device.
class Device {
  const Device({
    required this.peerId,
    required this.name,
    this.icon = 'device',
    this.trusted = false,
    this.lastSeenAt,
  });

  final String peerId;
  final String name;
  final String icon;
  final bool trusted;
  final DateTime? lastSeenAt;

  Device copyWith({
    String? name,
    String? icon,
    bool? trusted,
    DateTime? lastSeenAt,
  }) {
    return Device(
      peerId: peerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      trusted: trusted ?? this.trusted,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
