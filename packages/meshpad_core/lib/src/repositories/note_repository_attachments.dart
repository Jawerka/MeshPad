part of 'note_repository.dart';

mixin _NoteRepositoryAttachments
    on _NoteRepositoryHost, _NoteRepositoryInternals, _NoteRepositoryCrud {
  Future<Note> addAttachment(
    String id,
    String sourceFilePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw NoteNotFoundException(id);
    }
    if (existing.deleted) {
      throw NoteDeletedException(id);
    }

    final attachment = await copyAttachmentIntoNote(
      attachmentsDir: _paths.attachmentsDir(id),
      sourcePath: sourceFilePath,
      onProgress: onAttachmentProgress,
    );

    final updated = existing.copyWith(
      attachments: [...existing.attachments, attachment],
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    return updated;
  }

  Future<Note> addAttachmentFromBytes(
    String id, {
    required String fileName,
    required List<int> bytes,
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw NoteNotFoundException(id);
    }
    if (existing.deleted) {
      throw NoteDeletedException(id);
    }

    final attachment = await createAttachmentFromBytes(
      attachmentsDir: _paths.attachmentsDir(id),
      preferredName: fileName,
      bytes: bytes,
      onProgress: onAttachmentProgress,
    );

    final updated = existing.copyWith(
      attachments: [...existing.attachments, attachment],
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    return updated;
  }

  String attachmentPath(String noteId, String fileName) =>
      _paths.attachmentFile(noteId, fileName);

  Future<bool> attachmentMatches(String noteId, AttachmentMeta meta) {
    return attachmentFileMatches(
      File(attachmentPath(noteId, meta.name)),
      meta,
    );
  }

  Future<void> storeRemoteAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) async {
    await writeAttachmentBytes(
      attachmentsDir: _paths.attachmentsDir(noteId),
      meta: meta,
      bytes: bytes,
    );
  }

  Future<AttachmentUploadStatus?> attachmentUploadStatus(
    String noteId,
    String fileName,
  ) async {
    final note = await getNote(noteId);
    if (note == null) return null;

    AttachmentMeta? meta;
    for (final item in note.toMeta().attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }
    if (meta == null) return null;

    return attachment_upload.readAttachmentUploadStatus(
      attachmentsDir: _paths.attachmentsDir(noteId),
      fileName: fileName,
      meta: meta,
    );
  }

  Future<AttachmentUploadResult> receiveAttachmentUploadChunk({
    required String noteId,
    required String fileName,
    required int offset,
    required int totalSize,
    required String sha256,
    required List<int> bytes,
  }) async {
    final note = await getNote(noteId);
    if (note == null) {
      throw StateError('note not found');
    }

    AttachmentMeta? meta;
    for (final item in note.toMeta().attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }
    if (meta == null) {
      throw StateError('attachment not in note meta');
    }

    return attachment_upload.receiveAttachmentUploadChunk(
      attachmentsDir: _paths.attachmentsDir(noteId),
      meta: meta,
      offset: offset,
      totalSize: totalSize,
      sha256: sha256,
      bytes: bytes,
    );
  }

  Future<List<int>?> readAttachmentBytes(String noteId, String fileName) async {
    final file = File(attachmentPath(noteId, fileName));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Generates missing `.thumbs/` previews for indexed image attachments.
  Future<int> rebuildMissingImageThumbnails(MeshPadPaths paths) async {
    var rebuilt = 0;
    final ids = await _fs.listNoteIds(includeDeleted: false);
    for (final id in ids) {
      final note = await getNote(id);
      if (note == null) continue;
      for (final attachment in note.attachments) {
        if (!isImageAttachment(attachment)) continue;
        final attachmentFile = paths.attachmentFile(id, attachment.name);
        final thumbPath = paths.thumbFile(id, attachment.name);
        if (!await File(attachmentFile).exists()) continue;
        if (await File(thumbPath).exists()) continue;
        await ensureImageThumbnail(
          attachmentPath: attachmentFile,
          thumbsDir: paths.thumbsDir(id),
          attachmentName: attachment.name,
        );
        rebuilt++;
      }
    }
    return rebuilt;
  }
}
