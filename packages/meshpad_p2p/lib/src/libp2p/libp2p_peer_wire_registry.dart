import 'dart:convert';
import 'dart:io';

/// Maps remote peer IDs to sidecar wire base URLs (PLAN 8.2–8.3).
///
/// [remoteWireBaseFor] returns only **explicit** entries (env, [remember],
/// SSE `wire_base`). Inferred URLs from `lan_host` alone are stored for dev
/// hints but are not sent as `remote_wire_base` when the Rust sidecar can use
/// libp2p (`peer_id` only).
class Libp2pPeerWireRegistry {
  Libp2pPeerWireRegistry({Map<String, String>? initial})
      : _bases = {...?initial, ...wireBasesFromEnvironment()} {
    _explicit.addAll(_bases.keys);
  }

  final Map<String, String> _bases;
  final Set<String> _explicit = {};

  /// Explicit wire URL (dev harness, SSE `wire_base`, env map).
  void remember(String peerId, String wireBaseUrl) {
    final trimmed = wireBaseUrl.trim();
    _bases[peerId] = trimmed;
    _explicit.add(peerId);
  }

  /// Inferred URL (`http://<lan_host>:45839/`) — not used for Rust libp2p sync.
  void rememberInferred(String peerId, String wireBaseUrl) {
    _bases[peerId] = wireBaseUrl.trim();
    _explicit.remove(peerId);
  }

  void forget(String peerId) {
    _bases.remove(peerId);
    _explicit.remove(peerId);
  }

  String? wireBaseFor(String peerId) => _bases[peerId];

  /// Wire URL for `POST /v1/sync` `remote_wire_base` (explicit only).
  String? remoteWireBaseFor(String peerId) {
    if (!_explicit.contains(peerId)) return null;
    return _bases[peerId];
  }

  bool isExplicit(String peerId) => _explicit.contains(peerId);

  Map<String, String> get all => Map.unmodifiable(_bases);
}

const defaultPeerWirePort = 45839;

/// Port for [inferPeerWireBase] when only `lan_host` is known (dev harness).
int defaultPeerWirePortFromEnvironment() {
  const fromDefine = String.fromEnvironment('MESHPAD_DEFAULT_PEER_WIRE_PORT');
  if (fromDefine.isNotEmpty) {
    return int.tryParse(fromDefine) ?? defaultPeerWirePort;
  }
  final fromEnv = Platform.environment['MESHPAD_DEFAULT_PEER_WIRE_PORT'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return int.tryParse(fromEnv) ?? defaultPeerWirePort;
  }
  return defaultPeerWirePort;
}

/// Resolves a peer wire URL from SSE `wire_base` or `http://<lan_host>:<wirePort>/`.
String? inferPeerWireBase({
  String? explicitWireBase,
  String? lanHost,
  int? wirePort,
}) {
  if (explicitWireBase != null && explicitWireBase.trim().isNotEmpty) {
    return explicitWireBase.trim();
  }
  if (lanHost == null || lanHost.trim().isEmpty) return null;
  final port = wirePort ?? defaultPeerWirePortFromEnvironment();
  return 'http://${lanHost.trim()}:$port/';
}

/// `MESHPAD_PEER_WIRE_BASES` — JSON object `{ "peer-id": "http://127.0.0.1:45840/" }`.
Map<String, String> wireBasesFromEnvironment() {
  const fromDefine = String.fromEnvironment('MESHPAD_PEER_WIRE_BASES');
  final raw = fromDefine.isNotEmpty
      ? fromDefine
      : Platform.environment['MESHPAD_PEER_WIRE_BASES'];
  if (raw == null || raw.trim().isEmpty) return {};

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  } on Object {
    return {};
  }
}
