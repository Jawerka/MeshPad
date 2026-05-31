/// PIN pairing message shapes for libp2p MVP (PLAN §5.1).
class PinPairingOffer {
  const PinPairingOffer({
    required this.peerId,
    required this.displayName,
    required this.pin,
    required this.expiresAt,
  });

  final String peerId;
  final String displayName;
  final String pin;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'display_name': displayName,
        'pin': pin,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory PinPairingOffer.fromJson(Map<String, dynamic> json) {
    return PinPairingOffer(
      peerId: json['peer_id'] as String,
      displayName: json['display_name'] as String? ?? 'Устройство',
      pin: json['pin'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
    );
  }
}

class PinPairingConfirm {
  const PinPairingConfirm({
    required this.peerId,
    required this.pin,
    this.initiatorPeerId,
    this.initiatorDisplayName,
    this.initiatorLanHost,
    this.initiatorHttpPort,
  });

  final String peerId;
  final String pin;
  final String? initiatorPeerId;
  final String? initiatorDisplayName;
  final String? initiatorLanHost;
  final int? initiatorHttpPort;

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'pin': pin,
        if (initiatorPeerId != null) 'initiator_peer_id': initiatorPeerId,
        if (initiatorDisplayName != null)
          'initiator_display_name': initiatorDisplayName,
        if (initiatorLanHost != null) 'initiator_lan_host': initiatorLanHost,
        if (initiatorHttpPort != null)
          'initiator_http_port': initiatorHttpPort,
      };

  factory PinPairingConfirm.fromJson(Map<String, dynamic> json) {
    return PinPairingConfirm(
      peerId: json['peer_id'] as String,
      pin: json['pin'] as String,
      initiatorPeerId: json['initiator_peer_id'] as String?,
      initiatorDisplayName: json['initiator_display_name'] as String?,
      initiatorLanHost: json['initiator_lan_host'] as String?,
      initiatorHttpPort: json['initiator_http_port'] as int?,
    );
  }
}

/// Generates a 6-digit PIN for display during pairing.
String generatePairingPin() {
  final n = DateTime.now().microsecondsSinceEpoch % 900000 + 100000;
  return n.toString();
}

bool isValidPairingPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin.trim());
