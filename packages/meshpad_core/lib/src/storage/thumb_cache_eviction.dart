import 'dart:io';

import 'package:path/path.dart' as p;

/// Default thumbnail cache budget (PLAN §11.5.4).
const defaultThumbCacheMaxMb = 256;

const minThumbCacheMaxMb = 64;
const maxThumbCacheMaxMb = 2048;

int clampThumbCacheMaxMb(int mb) =>
    mb.clamp(minThumbCacheMaxMb, maxThumbCacheMaxMb);

class ThumbCacheFileEntry {
  const ThumbCacheFileEntry({
    required this.path,
    required this.size,
    required this.modified,
  });

  final String path;
  final int size;
  final DateTime modified;
}

class ThumbCacheEvictionResult {
  const ThumbCacheEvictionResult({
    required this.totalBytesBefore,
    required this.removedFiles,
    required this.freedBytes,
  });

  final int totalBytesBefore;
  final int removedFiles;
  final int freedBytes;

  int get totalBytesAfter => totalBytesBefore - freedBytes;
}

/// Lists JPEG files under `notes/*/.thumbs/`.
Future<List<ThumbCacheFileEntry>> listThumbCacheFiles(String notesRoot) async {
  final root = Directory(notesRoot);
  if (!await root.exists()) return const [];

  final entries = <ThumbCacheFileEntry>[];
  await for (final entity in root.list()) {
    if (entity is! Directory) continue;
    final thumbsDir = Directory(p.join(entity.path, '.thumbs'));
    if (!await thumbsDir.exists()) continue;
    await for (final fileEntity in thumbsDir.list()) {
      if (fileEntity is! File) continue;
      final stat = await fileEntity.stat();
      entries.add(
        ThumbCacheFileEntry(
          path: fileEntity.path,
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
  }
  return entries;
}

/// Deletes oldest previews until total size is at most [maxBytes] (LRU by mtime).
Future<ThumbCacheEvictionResult> evictThumbCache({
  required String notesRoot,
  required int maxBytes,
}) async {
  final entries = await listThumbCacheFiles(notesRoot);
  var total = entries.fold<int>(0, (sum, e) => sum + e.size);
  final before = total;

  if (maxBytes <= 0 || total <= maxBytes) {
    return ThumbCacheEvictionResult(
      totalBytesBefore: before,
      removedFiles: 0,
      freedBytes: 0,
    );
  }

  entries.sort((a, b) => a.modified.compareTo(b.modified));
  var removed = 0;
  var freed = 0;

  for (final entry in entries) {
    if (total <= maxBytes) break;
    final file = File(entry.path);
    if (!await file.exists()) continue;
    await file.delete();
    total -= entry.size;
    freed += entry.size;
    removed++;
  }

  return ThumbCacheEvictionResult(
    totalBytesBefore: before,
    removedFiles: removed,
    freedBytes: freed,
  );
}
