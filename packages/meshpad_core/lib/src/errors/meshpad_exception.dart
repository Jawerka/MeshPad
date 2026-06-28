/// Unified application errors for UI mapping (PLAN §7).
sealed class MeshPadException implements Exception {
  const MeshPadException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'MeshPadException($code): $message';
}

class NoteNotFoundException extends MeshPadException {
  const NoteNotFoundException(String id)
      : super('note_not_found', 'Заметка не найдена: $id');
}

class NoteDeletedException extends MeshPadException {
  const NoteDeletedException(String id)
      : super('note_deleted', 'Заметка в корзине: $id');
}

class SyncTransportException extends MeshPadException {
  const SyncTransportException(String message)
      : super('sync_transport', message);
}

class AttachmentNotFoundException extends MeshPadException {
  const AttachmentNotFoundException(String path)
      : super('attachment_missing', 'Файл не найден: $path');
}

class AttachmentUploadOffsetException extends MeshPadException {
  AttachmentUploadOffsetException(this.expectedOffset)
      : super(
          'upload_offset_mismatch',
          'Upload offset mismatch; expected $expectedOffset',
        );

  final int expectedOffset;
}

class AttachmentUploadRejectedException extends MeshPadException {
  const AttachmentUploadRejectedException(super.code, super.message);
}

String meshPadExceptionUserMessage(Object error) {
  if (error is MeshPadException) return error.message;
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Нет подключения к сети';
  }
  if (text.contains('TimeoutException')) {
    return 'Превышено время ожидания';
  }
  return 'Произошла ошибка: $text';
}
