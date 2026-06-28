import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/storage/app_settings.dart';
import 'package:meshpad/core/storage/scheduled_notes_backup.dart';

void main() {
  final t0 = DateTime.utc(2026, 6, 1, 12);

  test('isDue requires enabled directory and elapsed interval', () {
    expect(
      ScheduledNotesBackup.isDue(
        enabled: false,
        backupDirectory: '/backups',
        lastRunAt: null,
        intervalHours: 24,
        nowUtc: t0,
      ),
      isFalse,
    );
    expect(
      ScheduledNotesBackup.isDue(
        enabled: true,
        backupDirectory: null,
        lastRunAt: null,
        intervalHours: 24,
        nowUtc: t0,
      ),
      isFalse,
    );
    expect(
      ScheduledNotesBackup.isDue(
        enabled: true,
        backupDirectory: '/backups',
        lastRunAt: null,
        intervalHours: 24,
        nowUtc: t0,
      ),
      isTrue,
    );
    expect(
      ScheduledNotesBackup.isDue(
        enabled: true,
        backupDirectory: '/backups',
        lastRunAt: t0.subtract(const Duration(hours: 23)),
        intervalHours: 24,
        nowUtc: t0,
      ),
      isFalse,
    );
    expect(
      ScheduledNotesBackup.isDue(
        enabled: true,
        backupDirectory: '/backups',
        lastRunAt: t0.subtract(const Duration(hours: 24)),
        intervalHours: 24,
        nowUtc: t0,
      ),
      isTrue,
    );
  });

  test('settingsDue delegates to AppSettings fields', () {
    const settings = AppSettings(
      autoBackupEnabled: true,
      autoBackupDirectory: '/backups',
      autoBackupIntervalHours: 12,
      autoBackupLastAt: null,
    );
    expect(ScheduledNotesBackup.settingsDue(settings, t0), isTrue);
  });

  test('clampIntervalHours respects bounds', () {
    expect(ScheduledNotesBackup.clampIntervalHours(1), 6);
    expect(ScheduledNotesBackup.clampIntervalHours(24), 24);
    expect(ScheduledNotesBackup.clampIntervalHours(200), 168);
    expect(AppSettings.minAutoBackupIntervalHours, 6);
    expect(AppSettings.maxAutoBackupIntervalHours, 168);
  });
}
