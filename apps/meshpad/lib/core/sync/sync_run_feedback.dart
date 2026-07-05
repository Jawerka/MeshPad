import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/sync_providers.dart';

/// Shows a snackbar when manual sync did not fully succeed.
void showSyncRunFeedback(BuildContext context, SyncRunResult result) {
  if (result.status == SyncRunStatus.completed) return;
  if (result.status == SyncRunStatus.partial && result.message == null) return;

  final l10n = AppLocalizations.of(context);
  final message = switch (result.status) {
    SyncRunStatus.noPeers => result.message ?? l10n.syncNoTrustedDevices,
    SyncRunStatus.partial => result.message ?? l10n.syncPartialDefault,
    SyncRunStatus.failed => result.message ?? l10n.syncFailedDefault,
    SyncRunStatus.completed => '',
  };

  if (message.isEmpty) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
