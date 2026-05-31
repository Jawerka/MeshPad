import 'package:uuid/uuid.dart';

/// HTTP header: caller peer id (`devices/local_identity.json` → `peer_id`).
const meshpadSyncPeerIdHeader = 'X-MeshPad-Peer-Id';

/// HTTP header: shared secret from `devices/trusted/<peer_id>.json`.
const meshpadSyncAuthTokenHeader = 'X-MeshPad-Auth-Token';

/// Generates a shared LAN sync auth token (stored on both peers after pairing).
String generateSyncAuthToken([Uuid? uuid]) =>
    (uuid ?? const Uuid()).v4();
