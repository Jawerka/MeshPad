import 'dart:async';

import 'fake_sync_transport.dart';
import 'lan/lan_sync_transport.dart';
import 'libp2p/libp2p_sync_transport.dart';
import 'sync_transport.dart';

/// Disposes transports that expose native resources.
void disposeSyncTransport(SyncTransport transport) {
  switch (transport) {
    case FakeSyncTransport t:
      t.dispose();
    case LanSyncTransport t:
      t.dispose();
    case Libp2pSyncTransport t:
      t.dispose();
    default:
      unawaited(transport.stop());
  }
}

extension SyncTransportLifecycle on SyncTransport {
  void dispose() => disposeSyncTransport(this);
}
