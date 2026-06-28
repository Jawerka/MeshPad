import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;

import 'app_settings.dart';

/// Scheduled zip export of `notes/` (PLAN §11.9.3).
class ScheduledNotesBackup {
  ScheduledNotesBackup._();

  static const minIntervalHours = 6;
  static const maxIntervalHours = 168;
  static const defaultIntervalHours = 24;
  static const maxRetainedBackups = 7;

  static int clampIntervalHours(int hours) =>
      hours.clamp(minIntervalHours, maxIntervalHours);

  static bool isDue({
    required bool enabled,
    required String? backupDirectory,
    required DateTime? lastRunAt,
    required int intervalHours,
    required DateTime nowUtc,
  }) {
    if (!enabled) return false;
    final dir = backupDirectory?.trim();
    if (dir == null || dir.isEmpty) return false;
    if (lastRunAt == null) return true;
    final elapsed = nowUtc.difference(lastRunAt.toUtc());
    return elapsed >= Duration(hours: intervalHours);
  }

  static bool settingsDue(AppSettings settings, DateTime nowUtc) => isDue(
        enabled: settings.autoBackupEnabled,
        backupDirectory: settings.autoBackupDirectory,
        lastRunAt: settings.autoBackupLastAt,
        intervalHours: settings.autoBackupIntervalHours,
        nowUtc: nowUtc,
      );

  /// Exports notes to [backupDirectory] and updates [lastRunAt] when provided.
  static Future<int> exportToDirectory({
    required String dataDir,
    required String backupDirectory,
    DateTime? nowUtc,
  }) async {
    final when = (nowUtc ?? DateTime.now()).toUtc();
    final dir = Directory(backupDirectory);
    await dir.create(recursive: true);

    final zipPath = p.join(dir.path, _fileName(when));
    final count = await NotesArchive.exportToFile(
      paths: MeshPadPaths(dataDir),
      zipPath: zipPath,
    );
    await _pruneOldBackups(dir);
    MeshPadLog.metric('backup_notes', '$count');
    MeshPadLog.metric('backup_path', zipPath);
    return count;
  }

  static Future<int?> runIfDue({
    required String dataDir,
    required AppSettings settings,
    DateTime? nowUtc,
  }) async {
    final when = (nowUtc ?? DateTime.now()).toUtc();
    if (!settingsDue(settings, when)) return null;
    final dir = settings.autoBackupDirectory!.trim();
    return exportToDirectory(
      dataDir: dataDir,
      backupDirectory: dir,
      nowUtc: when,
    );
  }

  static String _fileName(DateTime utc) {
    final stamp =
        '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}_'
        '${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}';
    return 'meshpad-backup-$stamp.zip';
  }

  static Future<void> _pruneOldBackups(Directory dir) async {
    if (!await dir.exists()) return;
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.zip')) continue;
      if (!p.basename(entity.path).startsWith('meshpad-backup-')) continue;
      files.add(entity);
    }
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    for (final file in files.skip(maxRetainedBackups)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
