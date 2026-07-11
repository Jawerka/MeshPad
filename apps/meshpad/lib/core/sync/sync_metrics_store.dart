/// Recent LAN sync run summaries for Settings diagnostics.
class SyncMetricEntry {
  const SyncMetricEntry({
    required this.at,
    required this.status,
    this.noteCount = 0,
    this.succeededPeerCount = 0,
    this.failedPeerCount = 0,
    this.skippedPeerCount = 0,
    this.totalPeerCount = 0,
    this.message,
  });

  final DateTime at;
  final String status;
  final int noteCount;
  final int succeededPeerCount;
  final int failedPeerCount;
  final int skippedPeerCount;
  final int totalPeerCount;
  final String? message;
}

class SyncMetricsStore {
  SyncMetricsStore._();

  static final SyncMetricsStore instance = SyncMetricsStore._();

  final _entries = <SyncMetricEntry>[];

  void record(SyncMetricEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > 20) {
      _entries.removeRange(20, _entries.length);
    }
  }

  List<SyncMetricEntry> get recent => List.unmodifiable(_entries);

  void clear() => _entries.clear();

  String exportText() {
    if (_entries.isEmpty) return 'No sync runs recorded yet.';
    final buffer = StringBuffer();
    for (final entry in _entries) {
      buffer.writeln(
        '${entry.at.toUtc().toIso8601String()} '
        '${entry.status} '
        'notes=${entry.noteCount} '
        'peers=${entry.succeededPeerCount}/${entry.totalPeerCount} '
        'failed=${entry.failedPeerCount} '
        'skipped=${entry.skippedPeerCount}'
        '${entry.message != null ? ' msg=${entry.message}' : ''}',
      );
    }
    return buffer.toString().trimRight();
  }
}
