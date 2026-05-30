import 'package:path/path.dart' as p;

/// Standard data directory layout (see PLAN.md).
class MeshPadPaths {
  MeshPadPaths(this.root);

  final String root;

  String get notesRoot => p.join(root, 'notes');
  String get devicesRoot => p.join(root, 'devices');
  String get syncRoot => p.join(root, 'sync');

  String noteDir(String id) => p.join(notesRoot, id);
}
