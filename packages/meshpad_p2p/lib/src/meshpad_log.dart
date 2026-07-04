import 'dart:developer' as developer;
import 'dart:io';

enum MeshPadLogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3);

  const MeshPadLogLevel(this.priority);
  final int priority;
}

/// Structured LAN/sync logging (IDE console, `adb logcat`, and optional log file).
abstract final class MeshPadLog {
  static var enabled = true;

  /// [MeshPadLogLevel.info] includes discovery/lan; [MeshPadLogLevel.debug] adds sync noise.
  static MeshPadLogLevel minLevel = MeshPadLogLevel.info;

  static IOSink? _sink;
  static const _maxLogBytes = 2 * 1024 * 1024;

  /// Append structured logs to [logFilePath] (e.g. `{dataDir}/meshpad.log`).
  static void configure({String? logFilePath}) {
    _sink?.close();
    _sink = null;
    if (logFilePath == null || logFilePath.trim().isEmpty) return;

    final file = File(logFilePath);
    file.parent.createSync(recursive: true);
    _rotateIfNeeded(file);
    _sink = file.openWrite(mode: FileMode.append);
  }

  static void discovery(String message) =>
      _write(MeshPadLogLevel.info, 'discovery', message);

  static void sync(String message) =>
      _write(MeshPadLogLevel.debug, 'sync', message);

  static void lan(String message) =>
      _write(MeshPadLogLevel.info, 'lan', message);

  /// Structured metric for sync/reconcile timing (PLAN §11, task 1.6).
  static void metric(String key, String value) =>
      _write(MeshPadLogLevel.info, 'metric', '$key=$value');

  static void pairing(String message) =>
      _write(MeshPadLogLevel.info, 'pairing', message);

  static void warn(String tag, String message) =>
      _write(MeshPadLogLevel.warn, tag, message);

  static void error(String tag, String message) =>
      _write(MeshPadLogLevel.error, tag, message);

  static void _rotateIfNeeded(File file) {
    if (!file.existsSync()) return;
    if (file.lengthSync() <= _maxLogBytes) return;
    final backup = File('${file.path}.1');
    if (backup.existsSync()) backup.deleteSync();
    file.renameSync(backup.path);
  }

  static void _write(MeshPadLogLevel level, String tag, String message) {
    if (!enabled || level.priority < minLevel.priority) return;
    final prefix = level == MeshPadLogLevel.error
        ? 'ERROR'
        : level == MeshPadLogLevel.warn
            ? 'WARN'
            : level.name.toUpperCase();
    final line = '[$prefix] [meshpad:$tag] $message';
    developer.log(message, name: 'meshpad:$tag', level: _developerLevel(level));
    // ignore: avoid_print
    print(line);
    final sink = _sink;
    if (sink == null) return;
    final stamp = DateTime.now().toIso8601String();
    sink.writeln('[$stamp] $line');
  }

  static int _developerLevel(MeshPadLogLevel level) {
    return switch (level) {
      MeshPadLogLevel.debug || MeshPadLogLevel.info => 500,
      MeshPadLogLevel.warn => 900,
      MeshPadLogLevel.error => 1000,
    };
  }
}
