import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meshpad_core/meshpad_core.dart';

import 'lan/lan_sync_coordinator.dart';
import 'lan/lan_single_peer_sync.dart';
import 'lan/lan_sync_codec.dart';
import 'lan/lan_sync_transfer_progress.dart';
import 'lan/lan_sync_transport.dart';
import 'lan/lan_network_profile.dart';

/// Progress event from the foreground sync isolate.
class SyncIsolateProgress {
  const SyncIsolateProgress.peer({
    required this.peerLabel,
    required this.completedPeers,
    required this.totalPeers,
  })  : kind = SyncIsolateProgressKind.peer,
        fileName = null,
        transferred = null,
        totalBytes = null;

  const SyncIsolateProgress.transfer({
    required this.fileName,
    required this.transferred,
    required this.totalBytes,
  })  : kind = SyncIsolateProgressKind.transfer,
        peerLabel = null,
        completedPeers = null,
        totalPeers = null;

  final SyncIsolateProgressKind kind;
  final String? peerLabel;
  final int? completedPeers;
  final int? totalPeers;
  final String? fileName;
  final int? transferred;
  final int? totalBytes;
}

enum SyncIsolateProgressKind { peer, transfer }

/// Serializable LAN endpoint for isolate handoff.
Map<String, dynamic> lanPeerEndpointToJson(LanPeerEndpoint endpoint) => {
      'peerId': endpoint.peerId,
      'displayName': endpoint.displayName,
      'host': endpoint.host,
      'httpPort': endpoint.httpPort,
      if (endpoint.tlsPort != null) 'tlsPort': endpoint.tlsPort,
    };

LanPeerEndpoint lanPeerEndpointFromJson(Map<String, dynamic> json) {
  return LanPeerEndpoint(
    peerId: json['peerId'] as String,
    displayName: json['displayName'] as String,
    host: json['host'] as String,
    httpPort: json['httpPort'] as int,
    tlsPort: json['tlsPort'] as int?,
  );
}

class ForegroundSyncIsolateArgs {
  const ForegroundSyncIsolateArgs({
    required this.dataDir,
    required this.defaultAuthor,
    required this.networkProfileName,
    required this.localPeerId,
    required this.resolvedEndpoints,
    required this.authTokens,
    this.excludePeerIds = const [],
    this.propagateCascade = true,
    this.hopLimit,
    this.signingKeyBase64,
    this.tlsRootPath,
    this.enableTls = true,
    required this.progressPort,
  });

  final String dataDir;
  final String defaultAuthor;
  final String networkProfileName;
  final String localPeerId;
  final List<Map<String, dynamic>> resolvedEndpoints;
  final Map<String, String> authTokens;
  final List<String> excludePeerIds;
  final bool propagateCascade;
  final int? hopLimit;
  final String? signingKeyBase64;
  final String? tlsRootPath;
  final bool enableTls;
  final SendPort progressPort;
}

class _MapPeerAuthTokenStore implements PeerAuthTokenStore {
  _MapPeerAuthTokenStore(this._tokens);

  final Map<String, String> _tokens;

  @override
  Future<String?> read(String peerId) async => _tokens[peerId];

  @override
  Future<void> write(String peerId, String token) async {
    _tokens[peerId] = token;
  }

  @override
  Future<void> delete(String peerId) async {
    _tokens.remove(peerId);
  }
}

class _MemorySigningKeyStore implements DeviceSigningKeyStore {
  _MemorySigningKeyStore(this._bytes);

  final Uint8List? _bytes;

  @override
  Future<Uint8List?> readPrivateKey() async => _bytes;

  @override
  Future<void> writePrivateKey(Uint8List bytes) async {}

  @override
  Future<void> delete() async {}
}

void _sendProgress(SendPort port, SyncIsolateProgress progress) {
  switch (progress.kind) {
    case SyncIsolateProgressKind.peer:
      port.send({
        'type': 'peer',
        'label': progress.peerLabel,
        'completed': progress.completedPeers,
        'total': progress.totalPeers,
      });
    case SyncIsolateProgressKind.transfer:
      port.send({
        'type': 'transfer',
        'fileName': progress.fileName,
        'transferred': progress.transferred,
        'total': progress.totalBytes,
      });
  }
}

SyncIsolateProgress? _parseProgressMessage(Object? message) {
  if (message is! Map) return null;
  final type = message['type'];
  if (type == 'peer') {
    return SyncIsolateProgress.peer(
      peerLabel: message['label'] as String,
      completedPeers: message['completed'] as int,
      totalPeers: message['total'] as int,
    );
  }
  if (type == 'transfer') {
    return SyncIsolateProgress.transfer(
      fileName: message['fileName'] as String,
      transferred: message['transferred'] as int,
      totalBytes: message['total'] as int,
    );
  }
  return null;
}

LanNetworkProfile _networkProfileFromName(String name) {
  return LanNetworkProfile.values.firstWhere(
    (profile) => profile.name == name,
    orElse: () => LanNetworkProfile.normal,
  );
}

Future<LanSyncRunResult> _runForegroundSyncIsolateBody(
  ForegroundSyncIsolateArgs args,
) async {
  final db = createMeshPadDatabase(args.dataDir);
  final progressReporter = LanSyncTransferProgress(
    onProgress: (fileName, transferred, total) {
      _sendProgress(
        args.progressPort,
        SyncIsolateProgress.transfer(
          fileName: fileName,
          transferred: transferred,
          totalBytes: total,
        ),
      );
    },
  );
  lanSyncTransferProgress.onProgress = progressReporter.onProgress;

  try {
    final paths = MeshPadPaths(args.dataDir);
    final deviceStore = DeviceIdentityStore(
      paths: paths,
      authTokens: _MapPeerAuthTokenStore(Map.of(args.authTokens)),
      signingKeys: args.signingKeyBase64 == null
          ? FileDeviceSigningKeyStore(paths)
          : _MemorySigningKeyStore(
              Uint8List.fromList(base64Decode(args.signingKeyBase64!)),
            ),
    );
    final identity = await deviceStore.loadOrCreateIdentity(
      defaultDisplayName: args.defaultAuthor,
    );
    final repo = createNoteRepository(
      dataDir: args.dataDir,
      defaultAuthor: args.defaultAuthor,
      database: db,
    );
    final engine = SyncEngine(notes: repo, identity: identity);
    final networkProfile = _networkProfileFromName(args.networkProfileName);

    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => deviceStore,
      getTlsRoot: args.tlsRootPath != null && args.enableTls
          ? (_) async => args.tlsRootPath!
          : null,
      networkProfile: networkProfile,
      outboundOnly: true,
      enableTls: args.enableTls,
    );

    for (final json in args.resolvedEndpoints) {
      transport.rememberEndpoint(lanPeerEndpointFromJson(json));
    }

    await transport.start();

    final coordinator = LanSyncCoordinator(deviceStore: deviceStore);
    final profile = LanNetworkProfileSettings.forProfile(networkProfile);
    return coordinator.syncTrustedPeers(
      transport: transport,
      repository: repo,
      excludePeerIds: args.excludePeerIds,
      localPeerId: args.localPeerId,
      propagateCascade: args.propagateCascade,
      hopLimit: args.hopLimit ?? profile.cascadeHopLimit,
      maxConcurrentPeers: profile.maxConcurrentPeers,
      manageTransport: false,
      onPeerProgress: ({required peer, required completed, required total}) {
        _sendProgress(
          args.progressPort,
          SyncIsolateProgress.peer(
            peerLabel: 'Синхронизация с ${peer.name}',
            completedPeers: completed,
            totalPeers: total,
          ),
        );
      },
    );
  } finally {
    lanSyncTransferProgress.onProgress = null;
    await db.close();
  }
}

/// Runs outbound LAN sync off the UI isolate (PLAN §11.5.2 pattern).
Future<LanSyncRunResult> _spawnForegroundSyncIsolate(
  ForegroundSyncIsolateArgs args,
) {
  return Isolate.run(() => _runForegroundSyncIsolateBody(args));
}

Future<LanSyncRunResult> runForegroundSyncInIsolate({
  required String dataDir,
  required String defaultAuthor,
  required LanNetworkProfile networkProfile,
  required String localPeerId,
  required List<LanPeerEndpoint> resolvedEndpoints,
  required Map<String, String> authTokens,
  List<String> excludePeerIds = const [],
  bool propagateCascade = true,
  int? hopLimit,
  String? signingKeyBase64,
  String? tlsRootPath,
  bool enableTls = true,
  void Function(SyncIsolateProgress progress)? onProgress,
}) async {
  final receivePort = ReceivePort();
  final progressPort = receivePort.sendPort;
  final subscription = receivePort.listen((message) {
    final progress = _parseProgressMessage(message);
    if (progress != null) onProgress?.call(progress);
  });

  final args = ForegroundSyncIsolateArgs(
    dataDir: dataDir,
    defaultAuthor: defaultAuthor,
    networkProfileName: networkProfile.name,
    localPeerId: localPeerId,
    resolvedEndpoints: [
      for (final endpoint in resolvedEndpoints) lanPeerEndpointToJson(endpoint),
    ],
    authTokens: authTokens,
    excludePeerIds: excludePeerIds,
    propagateCascade: propagateCascade,
    hopLimit: hopLimit,
    signingKeyBase64: signingKeyBase64,
    tlsRootPath: tlsRootPath,
    enableTls: enableTls,
    progressPort: progressPort,
  );

  try {
    return await _spawnForegroundSyncIsolate(args);
  } finally {
    await subscription.cancel();
    receivePort.close();
  }
}

Future<Map<String, String>> collectPeerAuthTokens(
  DeviceIdentityStore store,
  Iterable<Device> peers,
) async {
  final tokens = <String, String>{};
  for (final peer in peers) {
    final token = await store.authTokenForPeer(peer.peerId);
    if (token != null && token.isNotEmpty) {
      tokens[peer.peerId] = token;
    }
  }
  return tokens;
}

void seedTransportEndpoints(
    LanSyncTransport transport, Iterable<Device> peers) {
  for (final peer in peers) {
    rememberPeerEndpoint(transport, peer);
  }
}

List<LanPeerEndpoint> collectResolvedEndpoints(
  LanSyncTransport transport,
  Iterable<Device> peers,
) {
  final endpoints = <LanPeerEndpoint>[];
  for (final peer in peers) {
    final endpoint =
        transport.endpointFor(peer.peerId) ?? storedEndpointForPeer(peer);
    if (endpoint != null) {
      endpoints.add(endpoint);
    }
  }
  return endpoints;
}

/// Resolves peer endpoints on [transport], then runs sync in a background isolate.
Future<LanSyncRunResult> runForegroundLanSync({
  required String dataDir,
  required String defaultAuthor,
  required LanNetworkProfile networkProfile,
  required String localPeerId,
  required DeviceIdentityStore deviceStore,
  required LanSyncTransport transport,
  required List<Device> trustedPeers,
  List<String> excludePeerIds = const [],
  bool propagateCascade = true,
  int? hopLimit,
  String? tlsRootPath,
  String? signingKeyBase64,
  bool enableTls = true,
  void Function(SyncIsolateProgress progress)? onProgress,
}) async {
  final excluded = excludePeerIds.toSet();
  final peers =
      trustedPeers.where((peer) => !excluded.contains(peer.peerId)).toList();
  if (peers.isEmpty) {
    return const LanSyncRunResult(
      LanSyncRunStatus.noPeers,
      message: 'Нет доверенных устройств',
    );
  }

  await transport.start();
  seedTransportEndpoints(transport, peers);
  final resolvedEndpoints = collectResolvedEndpoints(transport, peers);
  final authTokens = await collectPeerAuthTokens(deviceStore, peers);

  return runForegroundSyncInIsolate(
    dataDir: dataDir,
    defaultAuthor: defaultAuthor,
    networkProfile: networkProfile,
    localPeerId: localPeerId,
    resolvedEndpoints: resolvedEndpoints,
    authTokens: authTokens,
    excludePeerIds: excluded.toList(growable: false),
    propagateCascade: propagateCascade,
    hopLimit: hopLimit,
    signingKeyBase64: signingKeyBase64,
    tlsRootPath: tlsRootPath,
    enableTls: enableTls,
    onProgress: onProgress,
  );
}
