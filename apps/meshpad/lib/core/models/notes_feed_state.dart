import 'package:meshpad_core/meshpad_core.dart';

/// Paginated feed state (Sprint 6 — lazy list).
class NotesFeedState {
  const NotesFeedState({
    this.notes = const [],
    this.offset = 0,
    this.hasMoreOlder = false,
    this.isLoadingMore = false,
  });

  static const pageSize = 40;

  final List<Note> notes;
  final int offset;
  final bool hasMoreOlder;
  final bool isLoadingMore;

  NotesFeedState copyWith({
    List<Note>? notes,
    int? offset,
    bool? hasMoreOlder,
    bool? isLoadingMore,
  }) {
    return NotesFeedState(
      notes: notes ?? this.notes,
      offset: offset ?? this.offset,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
