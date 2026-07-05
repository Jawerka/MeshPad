import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live sync UI state (header spinner, transfer progress).
class SyncActivity {
  const SyncActivity({
    this.active = false,
    this.label,
    this.progress,
    this.completedPeers = 0,
    this.totalPeers = 0,
  });

  final bool active;
  final String? label;
  final double? progress;
  final int completedPeers;
  final int totalPeers;

  SyncActivity copyWith({
    bool? active,
    String? label,
    double? progress,
    bool clearProgress = false,
    int? completedPeers,
    int? totalPeers,
  }) {
    return SyncActivity(
      active: active ?? this.active,
      label: label ?? this.label,
      progress: clearProgress ? null : (progress ?? this.progress),
      completedPeers: completedPeers ?? this.completedPeers,
      totalPeers: totalPeers ?? this.totalPeers,
    );
  }
}

class SyncActivityNotifier extends Notifier<SyncActivity> {
  @override
  SyncActivity build() => const SyncActivity();

  void begin({required int totalPeers, String? label}) {
    state = SyncActivity(
      active: true,
      label: label ?? 'Синхронизация…',
      totalPeers: totalPeers,
      completedPeers: 0,
    );
  }

  void setPeer({
    required String label,
    required int completedPeers,
    required int totalPeers,
  }) {
    state = state.copyWith(
      active: true,
      label: label,
      completedPeers: completedPeers,
      totalPeers: totalPeers,
      clearProgress: true,
    );
  }

  void setTransfer({
    required String fileName,
    required int transferred,
    required int total,
  }) {
    final fraction = total <= 0 ? null : (transferred / total).clamp(0.0, 1.0);
    state = state.copyWith(
      active: true,
      label: total > 0 ? '$fileName ${(fraction! * 100).round()}%' : fileName,
      progress: fraction,
    );
  }

  void finish() {
    state = const SyncActivity();
  }
}

final syncActivityProvider =
    NotifierProvider<SyncActivityNotifier, SyncActivity>(
  SyncActivityNotifier.new,
);

/// Optional bridge for LAN attachment transfers.
final syncTransferReporterProvider = Provider<SyncTransferReporter>((ref) {
  final reporter = SyncTransferReporter();
  reporter.onProgress = (fileName, transferred, total) {
    ref.read(syncActivityProvider.notifier).setTransfer(
          fileName: fileName,
          transferred: transferred,
          total: total,
        );
  };
  ref.onDispose(reporter.dispose);
  return reporter;
});

class SyncTransferReporter {
  void Function(String fileName, int transferred, int total)? onProgress;

  Timer? _throttleTimer;
  String? _pendingFileName;
  int? _pendingTransferred;
  int? _pendingTotal;

  static const _throttleDelay = Duration(milliseconds: 150);

  void report({
    required String fileName,
    required int transferred,
    required int total,
  }) {
    _pendingFileName = fileName;
    _pendingTransferred = transferred;
    _pendingTotal = total;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(_throttleDelay, _flushProgress);
  }

  void _flushProgress() {
    final fileName = _pendingFileName;
    final transferred = _pendingTransferred;
    final total = _pendingTotal;
    if (fileName == null || transferred == null || total == null) return;
    onProgress?.call(fileName, transferred, total);
  }

  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    onProgress = null;
  }
}
