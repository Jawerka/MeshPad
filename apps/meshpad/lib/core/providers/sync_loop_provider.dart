import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'notes_providers.dart';
import 'network_sync_coordinator.dart';
import 'sync_providers.dart';

final syncLoopProvider = Provider<SyncLoopController>((ref) {
  final controller = SyncLoopController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Periodic sync while the app is running (desktop tray / mobile foreground).
class SyncLoopController {
  SyncLoopController(this._ref);

  final Ref _ref;
  Timer? _timer;
  var _syncInProgress = false;

  Future<void> start() async {
    await _restartTimer();
  }

  Future<void> reloadSettings() => _restartTimer();

  Future<void> _restartTimer() async {
    _timer?.cancel();
    _timer = null;

    final settings = await _ref.read(appSettingsStoreProvider).loadSettings();
    if (!settings.autoSyncEnabled) return;

    final interval = Duration(minutes: settings.autoSyncIntervalMinutes);
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));

    // First tick shortly after start when peers exist.
    unawaited(Future<void>.delayed(const Duration(seconds: 8), _tick));
  }

  Future<void> _tick() async {
    if (_syncInProgress) return;

    final settings = await _ref.read(appSettingsStoreProvider).loadSettings();
    if (!settings.autoSyncEnabled) return;

    final allowed =
        await _ref.read(networkSyncCoordinatorProvider).isSyncAllowed();
    if (!allowed) return;

    final trusted = await _ref.read(trustedDevicesProvider.future);
    if (trusted.isEmpty) return;

    _syncInProgress = true;
    try {
      final repo = await _ref.read(noteRepositoryProvider.future);
      await repo.purgeExpiredTrash();
      MeshPadLog.sync('auto-sync tick (${trusted.length} trusted peer(s))');
      await _ref.read(syncControllerProvider).runSync();
    } finally {
      _syncInProgress = false;
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
