/// PIN pairing message shapes for libp2p MVP (PLAN §5.1).
/// Default lifetime for an active PIN pairing offer (PLAN §12 A.3).
const pairingOfferTtl = Duration(minutes: 5);

/// Max failed `/pairing/confirm` attempts per client within [pairingConfirmRateWindow].
const pairingConfirmMaxAttempts = 5;

/// Sliding window for pairing confirm rate limiting.
const pairingConfirmRateWindow = Duration(minutes: 1);

class PinPairingOffer {
  const PinPairingOffer({
    required this.peerId,
    required this.displayName,
    required this.pin,
    required this.expiresAt,
    this.signingPublicKey,
    this.signingKeyAlgorithm,
  });

  final String peerId;
  final String displayName;
  final String pin;
  final DateTime expiresAt;
  final String? signingPublicKey;
  final String? signingKeyAlgorithm;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'display_name': displayName,
        'pin': pin,
        'expires_at': expiresAt.toIso8601String(),
        if (signingPublicKey != null) 'signing_public_key': signingPublicKey,
        if (signingKeyAlgorithm != null)
          'signing_key_algorithm': signingKeyAlgorithm,
      };

  factory PinPairingOffer.fromJson(Map<String, dynamic> json) {
    return PinPairingOffer(
      peerId: json['peer_id'] as String,
      displayName: json['display_name'] as String? ?? 'Устройство',
      pin: json['pin'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      signingPublicKey: json['signing_public_key'] as String?,
      signingKeyAlgorithm: json['signing_key_algorithm'] as String?,
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
    this.authToken,
    this.initiatorTlsCertSha256,
    this.initiatorSigningPublicKey,
    this.initiatorSigningKeyAlgorithm,
  });

  final String peerId;
  final String pin;
  final String? initiatorPeerId;
  final String? initiatorDisplayName;
  final String? initiatorLanHost;
  final int? initiatorHttpPort;
  final String? authToken;
  final String? initiatorTlsCertSha256;
  final String? initiatorSigningPublicKey;
  final String? initiatorSigningKeyAlgorithm;

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'pin': pin,
        if (initiatorPeerId != null) 'initiator_peer_id': initiatorPeerId,
        if (initiatorDisplayName != null)
          'initiator_display_name': initiatorDisplayName,
        if (initiatorLanHost != null) 'initiator_lan_host': initiatorLanHost,
        if (initiatorHttpPort != null) 'initiator_http_port': initiatorHttpPort,
        if (authToken != null) 'auth_token': authToken,
        if (initiatorTlsCertSha256 != null)
          'initiator_tls_cert_sha256': initiatorTlsCertSha256,
        if (initiatorSigningPublicKey != null)
          'initiator_signing_public_key': initiatorSigningPublicKey,
        if (initiatorSigningKeyAlgorithm != null)
          'initiator_signing_key_algorithm': initiatorSigningKeyAlgorithm,
      };

  factory PinPairingConfirm.fromJson(Map<String, dynamic> json) {
    return PinPairingConfirm(
      peerId: json['peer_id'] as String,
      pin: json['pin'] as String,
      initiatorPeerId: json['initiator_peer_id'] as String?,
      initiatorDisplayName: json['initiator_display_name'] as String?,
      initiatorLanHost: json['initiator_lan_host'] as String?,
      initiatorHttpPort: json['initiator_http_port'] as int?,
      authToken: json['auth_token'] as String?,
      initiatorTlsCertSha256: json['initiator_tls_cert_sha256'] as String?,
      initiatorSigningPublicKey:
          json['initiator_signing_public_key'] as String?,
      initiatorSigningKeyAlgorithm:
          json['initiator_signing_key_algorithm'] as String?,
    );
  }
}

/// Generates a 6-digit PIN for display during pairing.
String generatePairingPin() {
  final n = DateTime.now().microsecondsSinceEpoch % 900000 + 100000;
  return n.toString();
}

bool isValidPairingPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin.trim());

/// Builds a PIN offer with default [pairingOfferTtl].
PinPairingOffer createPairingOffer({
  required String peerId,
  required String displayName,
  required String pin,
  DateTime? expiresAt,
  String? signingPublicKey,
  String? signingKeyAlgorithm,
}) {
  final now = DateTime.now().toUtc();
  return PinPairingOffer(
    peerId: peerId,
    displayName: displayName,
    pin: pin,
    expiresAt: expiresAt ?? now.add(pairingOfferTtl),
    signingPublicKey: signingPublicKey,
    signingKeyAlgorithm: signingKeyAlgorithm,
  );
}

/// In-memory rate limiter for failed pairing confirm attempts (per client key).
class PairingConfirmRateLimiter {
  PairingConfirmRateLimiter({
    this.maxAttempts = pairingConfirmMaxAttempts,
    this.window = pairingConfirmRateWindow,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxAttempts;
  final Duration window;
  final DateTime Function() _now;

  final Map<String, _RateBucket> _buckets = {};

  bool isBlocked(String clientKey) {
    final bucket = _buckets[clientKey];
    if (bucket == null) return false;
    _prune(bucket);
    return bucket.failures.length >= maxAttempts;
  }

  void recordFailure(String clientKey) {
    final bucket = _buckets.putIfAbsent(clientKey, _RateBucket.new);
    _prune(bucket);
    bucket.failures.add(_now().toUtc());
  }

  void recordSuccess(String clientKey) => _buckets.remove(clientKey);

  void _prune(_RateBucket bucket) {
    final cutoff = _now().toUtc().subtract(window);
    bucket.failures.removeWhere((time) => time.isBefore(cutoff));
  }
}

class _RateBucket {
  final failures = <DateTime>[];
}

String pairingClientKeyFromAddress(Object? remoteAddress) {
  if (remoteAddress == null) return 'unknown';
  return remoteAddress.toString();
}
