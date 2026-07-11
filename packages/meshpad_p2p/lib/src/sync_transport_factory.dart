import 'package:meshpad_core/meshpad_core.dart';

import 'lan/lan_network_profile.dart';
import 'lan/lan_peer_server.dart';
import 'lan/lan_sync_transport.dart';
import 'sync_transport.dart';
import 'sync_transport_kind.dart';

/// Creates the configured [SyncTransport]. Production always uses [LanSyncTransport] (ADR 0003).
SyncTransport createSyncTransport({
  required SyncTransportKind kind,
  required Future<SyncEngine> Function() getEngine,
  required Future<LocalDeviceIdentity> Function() getIdentity,
  Future<DeviceIdentityStore> Function()? getDeviceStore,
  Future<String> Function(DeviceIdentityStore store)? getTlsRoot,
  String? announceHost,
  RemoteTrustedHandler? onRemoteTrusted,
  CascadeSyncHandler? onCascadeSync,
  LanNetworkProfile networkProfile = LanNetworkProfile.normal,
}) {
  return LanSyncTransport(
    getEngine: getEngine,
    getIdentity: getIdentity,
    getDeviceStore: getDeviceStore,
    getTlsRoot: getTlsRoot,
    announceHost: announceHost,
    onRemoteTrusted: onRemoteTrusted,
    onCascadeSync: onCascadeSync,
    networkProfile: networkProfile,
  );
}
