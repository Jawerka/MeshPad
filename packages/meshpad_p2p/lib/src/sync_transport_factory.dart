import 'package:meshpad_core/meshpad_core.dart';

import 'lan/lan_peer_server.dart';
import 'lan/lan_sync_transport.dart';
import 'libp2p/libp2p_sync_transport.dart';
import 'sync_transport.dart';
import 'sync_transport_kind.dart';

/// Creates the configured [SyncTransport] (PLAN §12 B.3).
SyncTransport createSyncTransport({
  required SyncTransportKind kind,
  required Future<SyncEngine> Function() getEngine,
  required Future<LocalDeviceIdentity> Function() getIdentity,
  Future<DeviceIdentityStore> Function()? getDeviceStore,
  String? announceHost,
  RemoteTrustedHandler? onRemoteTrusted,
  CascadeSyncHandler? onCascadeSync,
}) {
  switch (kind) {
    case SyncTransportKind.lan:
      return LanSyncTransport(
        getEngine: getEngine,
        getIdentity: getIdentity,
        getDeviceStore: getDeviceStore,
        announceHost: announceHost,
        onRemoteTrusted: onRemoteTrusted,
        onCascadeSync: onCascadeSync,
      );
    case SyncTransportKind.libp2p:
      return Libp2pSyncTransport(
        getEngine: getEngine,
        getIdentity: getIdentity,
        getDeviceStore: getDeviceStore,
        announceHost: announceHost,
        onRemoteTrusted: onRemoteTrusted,
        onCascadeSync: onCascadeSync,
      );
  }
}
