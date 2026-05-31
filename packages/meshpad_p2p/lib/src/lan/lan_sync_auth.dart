import 'package:meshpad_core/meshpad_core.dart';

/// Validates LAN sync HTTP auth headers against trusted peer records.
Future<LanSyncAuthFailure?> validateLanSyncAuth({
  required String? callerPeerId,
  required String? authToken,
  required Future<TrustedDeviceRecord?> Function(String peerId) lookupTrusted,
}) async {
  if (callerPeerId == null || callerPeerId.trim().isEmpty) {
    return LanSyncAuthFailure.unauthorized;
  }

  final record = await lookupTrusted(callerPeerId);
  if (record == null) {
    return LanSyncAuthFailure.forbidden;
  }

  final expected = record.authToken;
  if (expected != null) {
    if (authToken == null || authToken != expected) {
      return LanSyncAuthFailure.unauthorized;
    }
  }

  return null;
}

enum LanSyncAuthFailure {
  unauthorized,
  forbidden,
}

int statusCodeFor(LanSyncAuthFailure failure) => switch (failure) {
      LanSyncAuthFailure.unauthorized => 401,
      LanSyncAuthFailure.forbidden => 403,
    };

String bodyFor(LanSyncAuthFailure failure) => switch (failure) {
      LanSyncAuthFailure.unauthorized => 'unauthorized',
      LanSyncAuthFailure.forbidden => 'peer not trusted',
    };

bool isLanSyncPublicPath(String path) =>
    path == '/meshpad/p2p/health' ||
    path == '/meshpad/p2p/pairing/offer' ||
    path == '/meshpad/p2p/pairing/confirm';
