part of 'note_repository.dart';

mixin _NoteRepositoryReconcile
    on
        _NoteRepositoryHost,
        _NoteRepositoryInternals,
        _NoteRepositoryCrud,
        _NoteRepositoryAttachments {
  Future<NoteApplyResult> applyRemoteMerge(
    NoteMeta remoteMeta,
    String remoteMarkdown,
  ) async {
    final local = await getNote(remoteMeta.id);
    inspectRemoteNoteTimestamp(
      noteId: remoteMeta.id,
      remoteUpdatedAt: remoteMeta.updatedAt,
      localUpdatedAt: local?.updatedAt,
    );

    if (local == null) {
      final note = Note.fromMeta(meta: remoteMeta, markdown: remoteMarkdown);
      await _persist(note, enqueueOutbox: false);
      return NoteApplyResult.applied;
    }

    final outcome = resolveNoteConflict(
      local: local.toMeta(),
      remote: remoteMeta,
      localMarkdown: local.markdown,
      remoteMarkdown: remoteMarkdown,
    );

    switch (outcome) {
      case MergeOutcome.unchanged:
        return NoteApplyResult.unchanged;
      case MergeOutcome.appliedLocal:
        return NoteApplyResult.skippedLocalNewer;
      case MergeOutcome.createdConflictCopy:
        await NoteConflictCopyStore(noteDir: _paths.noteDir(local.id)).write(
          noteId: local.id,
          remoteMeta: remoteMeta,
          remoteMarkdown: remoteMarkdown,
        );
        return NoteApplyResult.conflictCopyCreated;
      case MergeOutcome.appliedRemote:
        final merged = mergeNoteMeta(local.toMeta(), remoteMeta)!;
        final note = Note.fromMeta(meta: merged, markdown: remoteMarkdown);
        await _persist(note, enqueueOutbox: false);
        return NoteApplyResult.applied;
    }
  }

  Future<List<NoteConflictCopy>> listConflictCopies(String noteId) =>
      NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).list();

  Future<({String title, String markdown})?> readConflictCopy(
    String noteId,
    String fileName,
  ) async {
    final parsed =
        await NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).read(
      fileName,
    );
    if (parsed == null) return null;
    return (title: parsed.title, markdown: parsed.markdown);
  }

  /// Replaces the note with a conflict copy and removes conflict files.
  Future<void> applyConflictCopy(String noteId, String fileName) async {
    final store = NoteConflictCopyStore(noteDir: _paths.noteDir(noteId));
    final parsed = await store.read(fileName);
    if (parsed == null) return;

    final existing = await getNote(noteId);
    if (existing == null) return;

    final updated = existing.copyWith(
      title: parsed.title.isNotEmpty ? parsed.title : existing.title,
      markdown: parsed.markdown,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    await store.deleteAll();
  }

  Future<void> dismissConflictCopies(String noteId) async {
    await NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).deleteAll();
  }

  /// Rebuild Drift index from file system (FS wins).
  ///
  /// When [thumbCacheMaxMb] is set, evicts oldest `.thumbs/` files over the budget
  /// after rebuilding missing previews (PLAN §11.5.4).
  Future<int> reconcileFromFilesystem({
    int? thumbCacheMaxMb,
    int isolateNoteThreshold = reconcileIsolateNoteThreshold,
  }) async {
    await purgeExpiredTrash();

    final dirIds = await _fs.listNoteDirectoryIds();
    if (dirIds.length > isolateNoteThreshold) {
      return runReconcileInIsolate(
        dataDir: _paths.root,
        defaultAuthor: defaultAuthor,
        thumbCacheMaxMb: thumbCacheMaxMb,
      );
    }

    final dirIdSet = dirIds.toSet();

    for (final id in await _db.listAllNoteIds()) {
      if (!dirIdSet.contains(id)) {
        await _db.deleteNoteRow(id);
      }
    }

    var count = 0;
    for (final id in dirIds) {
      final signatures = await readNoteFsSignatures(_paths, id);
      if (signatures == null) continue;

      final cached = await _db.getNoteFsSignatures(id);
      if (cached != null &&
          cached.meta != null &&
          cached.md != null &&
          signatures.matches(
            NoteFsSignatures(
              metaModifiedAt: cached.meta!,
              markdownModifiedAt: cached.md!,
              attachmentsModifiedAt: cached.attachments,
            ),
          )) {
        final meta = await _fs.readMeta(id);
        if (meta != null && await _driftIndexMatchesMeta(id, meta)) {
          continue;
        }
      }

      final folder = await _fs.read(id);
      if (folder == null) continue;
      var meta = folder.meta;
      final derivedTitle = titleFromMarkdown(folder.markdown);
      if (meta.title.trim().isEmpty && derivedTitle.isNotEmpty) {
        meta = NoteMeta(
          schemaVersion: meta.schemaVersion,
          id: meta.id,
          title: derivedTitle,
          createdAt: meta.createdAt,
          updatedAt: meta.updatedAt,
          author: meta.author,
          deleted: meta.deleted,
          deletedAt: meta.deletedAt,
          attachments: meta.attachments,
        );
        await _fs.write(
          NoteFolder(path: folder.path, meta: meta, markdown: folder.markdown),
        );
      }
      final note = Note.fromMeta(meta: meta, markdown: folder.markdown);
      await _indexNote(note, fsSignatures: signatures);
      count++;
    }
    await rebuildMissingImageThumbnails(_paths);
    if (thumbCacheMaxMb != null && thumbCacheMaxMb > 0) {
      await evictThumbCache(
        notesRoot: _paths.notesRoot,
        maxBytes: thumbCacheMaxMb * 1024 * 1024,
      );
    }
    return count;
  }
}
