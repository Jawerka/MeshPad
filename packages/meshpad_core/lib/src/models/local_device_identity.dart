import 'device.dart';

/// This device's identity (`devices/local_identity.json`).
class LocalDeviceIdentity {
  const LocalDeviceIdentity({
    required this.peerId,
    required this.displayName,
    this.icon = 'laptop',
    required this.createdAt,
  });

  final String peerId;
  final String displayName;
  final String icon;
  final DateTime createdAt;

  Device toDevice() => Device(
        peerId: peerId,
        name: displayName,
        icon: icon,
        trusted: true,
        lastSeenAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'display_name': displayName,
        'icon': icon,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory LocalDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return LocalDeviceIdentity(
      peerId: json['peer_id'] as String,
      displayName: json['display_name'] as String? ?? 'Устройство',
      icon: json['icon'] as String? ?? 'laptop',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}

/// Trusted peer record (`devices/trusted/<peer_id>.json`).
class TrustedDeviceRecord {
  const TrustedDeviceRecord({
    required this.peerId,
    required this.name,
    this.icon = 'device',
    required this.trustedAt,
    this.lastSeenAt,
  });

  final String peerId;
  final String name;
  final String icon;
  final DateTime trustedAt;
  final DateTime? lastSeenAt;

  Device toDevice() => Device(
        peerId: peerId,
        name: name,
        icon: icon,
        trusted: true,
        lastSeenAt: lastSeenAt,
      );

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'name': name,
        'icon': icon,
        'trusted_at': trustedAt.toUtc().toIso8601String(),
        'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
      };

  factory TrustedDeviceRecord.fromJson(Map<String, dynamic> json) {
    return TrustedDeviceRecord(
      peerId: json['peer_id'] as String,
      name: json['name'] as String? ?? 'Устройство',
      icon: json['icon'] as String? ?? 'device',
      trustedAt: DateTime.parse(json['trusted_at'] as String).toUtc(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String).toUtc()
          : null,
    );
  }
}
