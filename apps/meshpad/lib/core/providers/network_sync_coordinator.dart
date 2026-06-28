import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../storage/app_settings.dart';
import '../../platform/wifi_info.dart';
import 'discovery_providers.dart';
import 'notes_providers.dart';
import 'sync_providers.dart';

final networkSyncCoordinatorProvider = Provider<NetworkSyncCoordinator>((ref) {
  final coordinator = NetworkSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Starts/stops LAN discovery and sync based on connectivity and SSID policy.
class NetworkSyncCoordinator {
  NetworkSyncCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  var _lastAllowed = false;

  Future<void> start() async {
    if (kIsWeb) return;
    await _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_evaluate());
    });
    await _evaluate();
  }

  void dispose() => _sub?.cancel();

  Future<bool> isSyncAllowed() async {
    if (kIsWeb) return false;
    final results = await Connectivity().checkConnectivity();
    if (!_hasLanTransport(results)) return false;

    final settings = await _ref.read(appSettingsProvider.future);
    if (!settings.syncOnlyOnAllowedWifi) return true;
    if (settings.allowedWifiSsids.isEmpty) return true;
    if (!Platform.isAndroid) return true;

    final ssid = await WifiInfoPlatform.currentSsid();
    if (ssid == null || ssid.isEmpty) return false;
    return settings.allowedWifiSsids.contains(ssid);
  }

  Future<void> _evaluate() async {
    final allowed = await isSyncAllowed();
    if (allowed == _lastAllowed) return;
    _lastAllowed = allowed;

    if (!_supportedPlatform) return;

    final discovery = _ref.read(discoveryServiceProvider);
    if (allowed) {
      MeshPadLog.lan('network available — starting discovery');
      try {
        await discovery.ensureRunning();
        await _ref.read(syncControllerProvider).runSync();
      } catch (e, st) {
        MeshPadLog.warn('discovery', 'network coordinator start failed: $e');
        MeshPadLog.warn('discovery', '$st');
      }
    } else {
      MeshPadLog.lan('network not allowed — stopping discovery');
      try {
        await discovery.prepareForTransportChange();
      } catch (_) {}
    }
  }

  bool get _supportedPlatform =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isAndroid);

  bool _hasLanTransport(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }
}

/// Returns true when [settings] permit sync on the current network.
Future<bool> syncAllowedForSettings(
  AppSettings settings, {
  required Future<String?> Function() currentSsid,
  required Future<List<ConnectivityResult>> Function() connectivity,
}) async {
  final results = await connectivity();
  final hasLan = results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn,
  );
  if (!hasLan) return false;
  if (!settings.syncOnlyOnAllowedWifi) return true;
  if (settings.allowedWifiSsids.isEmpty) return true;
  final ssid = await currentSsid();
  if (ssid == null || ssid.isEmpty) return false;
  return settings.allowedWifiSsids.contains(ssid);
}
