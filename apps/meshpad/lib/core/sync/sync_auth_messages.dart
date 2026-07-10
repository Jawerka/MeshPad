import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../l10n/app_localizations.dart';

/// Local-only sync message codes (not from HTTP).
const syncSigningKeyResetCode = 'local:signing_key_reset';

/// Maps LAN sync auth HTTP bodies to localized user messages.
String syncAuthFailureMessage(String body, AppLocalizations l10n) {
  final failure = parseLanSyncAuthFailureBody(body);
  return switch (failure) {
    LanSyncAuthFailure.missingPeerId => l10n.syncRejectedMissingPeerId,
    LanSyncAuthFailure.invalidToken => l10n.syncRejectedInvalidKey,
    LanSyncAuthFailure.missingSignature => l10n.syncRejectedSignature,
    LanSyncAuthFailure.invalidSignature => l10n.syncRejectedSignature,
    LanSyncAuthFailure.clockSkew => l10n.syncRejectedClockSkew,
    LanSyncAuthFailure.forbidden => l10n.syncRejectedUntrusted,
    null => body,
  };
}

/// Resolves sync run messages that may contain auth failure bodies.
String syncRunUserMessage(String? message, AppLocalizations l10n) {
  if (message == null || message.isEmpty) return '';
  if (message == syncSigningKeyResetCode) return l10n.syncSigningKeyReset;
  final auth = parseLanSyncAuthFailureBody(message);
  if (auth != null) return syncAuthFailureMessage(message, l10n);
  return message;
}
