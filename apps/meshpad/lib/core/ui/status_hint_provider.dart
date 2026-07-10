import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatusHintSeverity { info, success, error }

class StatusHint {
  const StatusHint({
    required this.message,
    this.severity = StatusHintSeverity.info,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final StatusHintSeverity severity;
  final Duration duration;

  StatusHint copyWith({
    String? message,
    StatusHintSeverity? severity,
    Duration? duration,
  }) {
    return StatusHint(
      message: message ?? this.message,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
    );
  }
}

class StatusHintNotifier extends Notifier<StatusHint?> {
  Timer? _timer;
  var _generation = 0;

  @override
  StatusHint? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(
    String message, {
    StatusHintSeverity severity = StatusHintSeverity.info,
    Duration? duration,
  }) {
    _timer?.cancel();
    final effectiveDuration = duration ??
        (severity == StatusHintSeverity.error
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4));
    final generation = ++_generation;
    state = StatusHint(
      message: message,
      severity: severity,
      duration: effectiveDuration,
    );
    _timer = Timer(effectiveDuration, () {
      if (_generation == generation) dismiss();
    });
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    state = null;
  }
}

final statusHintProvider =
    NotifierProvider<StatusHintNotifier, StatusHint?>(StatusHintNotifier.new);
