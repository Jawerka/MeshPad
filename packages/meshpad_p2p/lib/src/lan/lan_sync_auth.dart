import 'package:meshpad_core/meshpad_core.dart';

/// LAN sync HTTP auth failure reason (also used as response body suffix).
enum LanSyncAuthFailure {
  missingPeerId,
  forbidden,
  invalidToken,
  missingSignature,
  invalidSignature,
  clockSkew,
}

/// Validates LAN sync HTTP auth headers against trusted peer records.
Future<LanSyncAuthFailure?> validateLanSyncAuth({
  required String? callerPeerId,
  required String? authToken,
  required String method,
  required String path,
  required String? timestampHeader,
  required String? signatureHeader,
  required Future<TrustedDeviceRecord?> Function(String peerId) lookupTrusted,
  DateTime? nowUtc,
}) async {
  if (callerPeerId == null || callerPeerId.trim().isEmpty) {
    return LanSyncAuthFailure.missingPeerId;
  }

  final record = await lookupTrusted(callerPeerId);
  if (record == null) {
    return LanSyncAuthFailure.forbidden;
  }

  final expected = record.authToken;
  if (expected != null) {
    if (authToken == null || authToken != expected) {
      return LanSyncAuthFailure.invalidToken;
    }
  }

  final peerSigningKey = record.signingPublicKey;
  if (peerSigningKey != null && peerSigningKey.isNotEmpty) {
    if (timestampHeader == null ||
        timestampHeader.isEmpty ||
        signatureHeader == null ||
        signatureHeader.isEmpty) {
      return LanSyncAuthFailure.missingSignature;
    }

    final ts = DateTime.tryParse(timestampHeader)?.toUtc();
    if (ts == null) {
      return LanSyncAuthFailure.invalidSignature;
    }

    final now = (nowUtc ?? DateTime.now()).toUtc();
    if (now.difference(ts).abs() > syncSignatureMaxSkew) {
      return LanSyncAuthFailure.clockSkew;
    }

    final ok = await verifySyncRequestSignature(
      peerId: callerPeerId,
      publicKeyBase64: peerSigningKey,
      timestampIso: timestampHeader,
      method: method,
      path: path,
      signatureBase64: signatureHeader,
      nowUtc: nowUtc,
    );
    if (!ok) {
      return LanSyncAuthFailure.invalidSignature;
    }
  }

  return null;
}

int statusCodeFor(LanSyncAuthFailure failure) => switch (failure) {
      LanSyncAuthFailure.missingPeerId ||
      LanSyncAuthFailure.invalidToken ||
      LanSyncAuthFailure.missingSignature ||
      LanSyncAuthFailure.invalidSignature ||
      LanSyncAuthFailure.clockSkew =>
        401,
      LanSyncAuthFailure.forbidden => 403,
    };

String bodyFor(LanSyncAuthFailure failure) => switch (failure) {
      LanSyncAuthFailure.missingPeerId => 'unauthorized:missing_peer_id',
      LanSyncAuthFailure.invalidToken => 'unauthorized:token',
      LanSyncAuthFailure.missingSignature => 'unauthorized:missing_signature',
      LanSyncAuthFailure.invalidSignature => 'unauthorized:signature',
      LanSyncAuthFailure.clockSkew => 'unauthorized:clock_skew',
      LanSyncAuthFailure.forbidden => 'peer not trusted',
    };

/// Parses auth failure from HTTP response body (legacy `unauthorized` included).
LanSyncAuthFailure? parseLanSyncAuthFailureBody(String body) {
  final trimmed = body.trim();
  return switch (trimmed) {
    'unauthorized:missing_peer_id' => LanSyncAuthFailure.missingPeerId,
    'unauthorized:token' => LanSyncAuthFailure.invalidToken,
    'unauthorized:missing_signature' => LanSyncAuthFailure.missingSignature,
    'unauthorized:signature' => LanSyncAuthFailure.invalidSignature,
    'unauthorized:clock_skew' => LanSyncAuthFailure.clockSkew,
    'unauthorized' => LanSyncAuthFailure.invalidToken,
    'peer not trusted' => LanSyncAuthFailure.forbidden,
    _ => null,
  };
}

bool isLanSyncPublicPath(String path) =>
    path == '/meshpad/p2p/health' ||
    path == '/meshpad/p2p/pairing/offer' ||
    path == '/meshpad/p2p/pairing/confirm';
