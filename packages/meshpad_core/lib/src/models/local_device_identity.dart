import 'device.dart';

/// This device's identity (`devices/local_identity.json`).
class LocalDeviceIdentity {
  const LocalDeviceIdentity({
    required this.peerId,
    required this.displayName,
    this.icon = 'laptop',
    required this.createdAt,
    this.signingPublicKey,
    this.signingKeyAlgorithm,
  });

  final String peerId;
  final String displayName;
  final String icon;
  final DateTime createdAt;
  /// Base64-encoded Ed25519 public key (32 bytes), when [signingKeyAlgorithm] is set.
  final String? signingPublicKey;
  final String? signingKeyAlgorithm;

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
        if (signingPublicKey != null && signingPublicKey!.isNotEmpty)
          'signing_public_key': signingPublicKey,
        if (signingKeyAlgorithm != null && signingKeyAlgorithm!.isNotEmpty)
          'signing_key_algorithm': signingKeyAlgorithm,
      };

  factory LocalDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return LocalDeviceIdentity(
      peerId: json['peer_id'] as String,
      displayName: json['display_name'] as String? ?? 'Устройство',
      icon: json['icon'] as String? ?? 'laptop',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      signingPublicKey: json['signing_public_key'] as String?,
      signingKeyAlgorithm: json['signing_key_algorithm'] as String?,
    );
  }
}

/// Trusted peer record (`devices/trusted/<peer_id>.json`).
class TrustedDeviceRecord {
  const   TrustedDeviceRecord({
    required this.peerId,
    required this.name,
    this.icon = 'device',
    required this.trustedAt,
    this.lastSeenAt,
    this.lanHost,
    this.lanHttpPort,
    this.authToken,
    this.tlsCertSha256,
    this.signingPublicKey,
    this.signingKeyAlgorithm,
  });

  final String peerId;
  final String name;
  final String icon;
  final DateTime trustedAt;
  final DateTime? lastSeenAt;
  final String? lanHost;
  final int? lanHttpPort;
  final String? authToken;
  final String? tlsCertSha256;
  final String? signingPublicKey;
  final String? signingKeyAlgorithm;

  Device toDevice() => Device(
        peerId: peerId,
        name: name,
        icon: icon,
        trusted: true,
        lastSeenAt: lastSeenAt,
        lanHost: lanHost,
        lanHttpPort: lanHttpPort,
      );

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'name': name,
        'icon': icon,
        'trusted_at': trustedAt.toUtc().toIso8601String(),
        'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
        if (lanHost != null) 'lan_host': lanHost,
        if (lanHttpPort != null) 'lan_http_port': lanHttpPort,
        if (authToken != null) 'auth_token': authToken,
        if (tlsCertSha256 != null) 'tls_cert_sha256': tlsCertSha256,
        if (signingPublicKey != null) 'signing_public_key': signingPublicKey,
        if (signingKeyAlgorithm != null)
          'signing_key_algorithm': signingKeyAlgorithm,
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
      lanHost: json['lan_host'] as String?,
      lanHttpPort: json['lan_http_port'] as int?,
      authToken: json['auth_token'] as String?,
      tlsCertSha256: json['tls_cert_sha256'] as String?,
      signingPublicKey: json['signing_public_key'] as String?,
      signingKeyAlgorithm: json['signing_key_algorithm'] as String?,
    );
  }

  TrustedDeviceRecord copyWith({
    String? name,
    String? icon,
    DateTime? trustedAt,
    DateTime? lastSeenAt,
    String? lanHost,
    int? lanHttpPort,
    String? authToken,
    bool clearAuthToken = false,
    String? tlsCertSha256,
    String? signingPublicKey,
    String? signingKeyAlgorithm,
    bool clearLanHost = false,
    bool clearLanHttpPort = false,
  }) {
    return TrustedDeviceRecord(
      peerId: peerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      trustedAt: trustedAt ?? this.trustedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lanHost: clearLanHost ? null : (lanHost ?? this.lanHost),
      lanHttpPort: clearLanHttpPort ? null : (lanHttpPort ?? this.lanHttpPort),
      authToken: clearAuthToken ? null : (authToken ?? this.authToken),
      tlsCertSha256: tlsCertSha256 ?? this.tlsCertSha256,
      signingPublicKey: signingPublicKey ?? this.signingPublicKey,
      signingKeyAlgorithm: signingKeyAlgorithm ?? this.signingKeyAlgorithm,
    );
  }

  /// JSON for disk when tokens are stored externally (no `auth_token` field).
  Map<String, dynamic> toPublicJson() {
    final json = Map<String, dynamic>.from(toJson());
    json.remove('auth_token');
    return json;
  }
}
