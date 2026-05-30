import 'note.dart';

/// FTS search result with highlighted snippet text.
class NoteSearchHit {
  const NoteSearchHit({required this.note, required this.snippet});

  final Note note;
  final String snippet;
}
