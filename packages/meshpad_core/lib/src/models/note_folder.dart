import 'note_meta.dart';

/// In-memory view of a note directory on disk.
class NoteFolder {
  const NoteFolder({
    required this.path,
    required this.meta,
    required this.markdown,
  });

  final String path;
  final NoteMeta meta;
  final String markdown;
}
