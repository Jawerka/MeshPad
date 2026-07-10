import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_hint_provider.dart';

void showMeshPadHint(
  BuildContext context,
  String message, {
  StatusHintSeverity severity = StatusHintSeverity.info,
  Duration? duration,
}) {
  ProviderScope.containerOf(context, listen: false)
      .read(statusHintProvider.notifier)
      .show(message, severity: severity, duration: duration);
}
