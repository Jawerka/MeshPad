import 'dart:async';

/// Server-side feed change notification (PLAN §12 D.1).
class NoteChangeEvent {
  const NoteChangeEvent({required this.type, this.noteId});

  final String type;
  final String? noteId;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (noteId != null) 'note_id': noteId,
      };
}

/// Broadcast hub for SSE `/api/events` subscribers.
class NoteChangeHub {
  final _controller = StreamController<NoteChangeEvent>.broadcast();

  Stream<NoteChangeEvent> get stream => _controller.stream;

  void noteCreated(String noteId) =>
      _emit(NoteChangeEvent(type: 'note_created', noteId: noteId));

  void noteUpdated(String noteId) =>
      _emit(NoteChangeEvent(type: 'note_updated', noteId: noteId));

  void noteDeleted(String noteId) =>
      _emit(NoteChangeEvent(type: 'note_deleted', noteId: noteId));

  void noteRestored(String noteId) =>
      _emit(NoteChangeEvent(type: 'note_restored', noteId: noteId));

  void attachmentAdded(String noteId) =>
      _emit(NoteChangeEvent(type: 'note_attachment', noteId: noteId));

  void feedChanged() => _emit(const NoteChangeEvent(type: 'feed_changed'));

  void _emit(NoteChangeEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() => _controller.close();
}
