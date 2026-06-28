import '../models/local_device_identity.dart';
import '../models/note.dart';
import '../models/note_head.dart';
import '../models/note_meta.dart';
import '../models/sync_event.dart';
import '../repositories/note_repository.dart';
import 'catalog_delta.dart';
import '../sync/lww_merge.dart';
import 'remote_note_snapshot.dart';

/// Read-only view of a peer used during sync.
abstract class SyncPeer {
  Future<List<NoteHead>> fetchCatalog();
  Future<RemoteNoteSnapshot?> fetchNote(String id);
}

/// Exposes a [SyncEngine] as a [SyncPeer].
class EngineSyncPeer implements SyncPeer {
  EngineSyncPeer(this.engine);

  final SyncEngine engine;

  @override
  Future<List<NoteHead>> fetchCatalog() => engine.localCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) => engine.exportNote(id);
}

class SyncSessionResult {
  const SyncSessionResult({
    required this.pulled,
    required this.receivedByPeer,
    required this.acknowledged,
    this.failedPushNoteIds = const [],
  });

  final int pulled;
  final int receivedByPeer;
  final int acknowledged;
  final List<String> failedPushNoteIds;

  int get total => pulled + receivedByPeer;
}

/// Coordinates catalog exchange, LWW merge, and outbox acknowledgement.
class SyncEngine {
  SyncEngine({
    required this.notes,
    required this.identity,
  });

  final NoteRepository notes;
  final LocalDeviceIdentity identity;

  Future<List<NoteHead>> localCatalog() => notes.catalogHeads();

  Future<RemoteNoteSnapshot?> exportNote(String id) async {
    final note = await notes.getNote(id);
    if (note == null) return null;
    return RemoteNoteSnapshot(meta: note.toMeta(), markdown: note.markdown);
  }

  Future<NoteApplyResult> applyRemote(RemoteNoteSnapshot remote) {
    return notes.applyRemoteMerge(remote.meta, remote.markdown);
  }

  Future<int> pullFrom(SyncPeer peer) async {
    final remoteHeads = await peer.fetchCatalog();
    final localById = {
      for (final head in await notes.catalogHeads()) head.id: head,
    };
    var applied = 0;

    for (final head in remoteHeads) {
      if (!noteHeadNeedsRemotePull(
        localHead: localById[head.id],
        remoteHead: head,
      )) {
        continue;
      }

      final snapshot = await peer.fetchNote(head.id);
      if (snapshot == null) continue;

      final result = await applyRemote(snapshot);
      if (result == NoteApplyResult.applied ||
          result == NoteApplyResult.conflictCopyCreated) {
        applied++;
      }
    }

    return applied;
  }

  Future<int> acknowledgeSyncedWith(SyncPeer peer) async {
    final peerIds = (await peer.fetchCatalog()).map((h) => h.id).toSet();
    final outbox = await notes.listOutbox();
    var cleared = 0;

    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      if (peerIds.contains(entry.entityId)) {
        await notes.removeOutboxEntry(entry.id);
        cleared++;
      }
    }

    return cleared;
  }

  Future<SyncSessionResult> syncWith(SyncEngine remote) async {
    final remotePeer = EngineSyncPeer(remote);
    final localPeer = EngineSyncPeer(this);

    final pulled = await pullFrom(remotePeer);
    final receivedByPeer = await remote.pullFrom(localPeer);
    final acknowledged = await acknowledgeSyncedWith(remotePeer);
    await remote.acknowledgeSyncedWith(localPeer);

    return SyncSessionResult(
      pulled: pulled,
      receivedByPeer: receivedByPeer,
      acknowledged: acknowledged,
    );
  }
}

/// Bidirectional sync helper for tests and paired fake transport.
Future<SyncSessionResult> syncEngines(SyncEngine a, SyncEngine b) =>
    a.syncWith(b);

NoteHead noteToHead(Note note) => NoteHead(
      id: note.id,
      updatedAt: note.updatedAt,
      deleted: note.deleted,
    );

NoteMeta? mergeRemoteMeta(NoteMeta? local, NoteMeta? remote) =>
    mergeNoteMeta(local, remote);
