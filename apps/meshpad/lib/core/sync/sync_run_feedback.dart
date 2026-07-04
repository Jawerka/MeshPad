import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/sync_providers.dart';

/// Shows a snackbar when manual sync did not fully succeed.
void showSyncRunFeedback(BuildContext context, SyncRunResult result) {
  if (result.status == SyncRunStatus.completed) return;

  final l10n = AppLocalizations.of(context);
  final message = switch (result.status) {
    SyncRunStatus.noPeers => result.message ?? l10n.syncNoTrustedDevices,
    SyncRunStatus.partial => result.message ?? l10n.syncPartialDefault,
    SyncRunStatus.failed => result.message ?? l10n.syncFailedDefault,
    SyncRunStatus.completed => '',
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
