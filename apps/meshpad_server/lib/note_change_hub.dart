import 'dart:async';

/// Server-side feed change notification (PLAN §12 D.1, §11.6.1).
class NoteChangeEvent {
  const NoteChangeEvent({
    required this.id,
    required this.type,
    this.noteId,
  });

  final int id;
  final String type;
  final String? noteId;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (noteId != null) 'note_id': noteId,
      };
}

/// Broadcast hub for SSE `/api/events` subscribers with replay buffer.
class NoteChangeHub {
  static const maxHistory = 500;

  final _controller = StreamController<NoteChangeEvent>.broadcast();
  final _history = <NoteChangeEvent>[];
  var _nextId = 1;

  Stream<NoteChangeEvent> get stream => _controller.stream;

  /// Events with [id] greater than [lastEventId] (for SSE reconnect).
  List<NoteChangeEvent> eventsAfter(int? lastEventId) {
    if (lastEventId == null) return const [];
    return _history.where((e) => e.id > lastEventId).toList();
  }

  void noteCreated(String noteId) =>
      _emit(type: 'note_created', noteId: noteId);

  void noteUpdated(String noteId) =>
      _emit(type: 'note_updated', noteId: noteId);

  void noteDeleted(String noteId) =>
      _emit(type: 'note_deleted', noteId: noteId);

  void noteRestored(String noteId) =>
      _emit(type: 'note_restored', noteId: noteId);

  void attachmentAdded(String noteId) =>
      _emit(type: 'note_attachment', noteId: noteId);

  void feedChanged() => _emit(type: 'feed_changed');

  void _emit({required String type, String? noteId}) {
    final event = NoteChangeEvent(id: _nextId++, type: type, noteId: noteId);
    _history.add(event);
    while (_history.length > maxHistory) {
      _history.removeAt(0);
    }
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() => _controller.close();
}
