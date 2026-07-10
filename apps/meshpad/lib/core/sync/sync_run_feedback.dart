import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import 'sync_result_hint.dart';

/// Shows a status hint when manual sync did not fully succeed.
void showSyncRunFeedback(BuildContext context, SyncRunResult result) {
  showSyncResultHint(ProviderScope.containerOf(context, listen: false), result);
}
