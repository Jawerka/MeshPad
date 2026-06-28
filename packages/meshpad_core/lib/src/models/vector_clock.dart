/// Vector clock helpers for optional `meta.json` field (PLAN §11.3.3).
Map<String, int> mergeVectorClocks(
  Map<String, int> local,
  Map<String, int> remote,
) {
  final merged = Map<String, int>.from(local);
  for (final entry in remote.entries) {
    final current = merged[entry.key] ?? 0;
    if (entry.value > current) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

/// True when neither clock dominates the other (concurrent edit hint).
bool vectorClocksAreConcurrent(
  Map<String, int> local,
  Map<String, int> remote,
) {
  var localNewer = false;
  var remoteNewer = false;
  final keys = {...local.keys, ...remote.keys};
  for (final key in keys) {
    final l = local[key] ?? 0;
    final r = remote[key] ?? 0;
    if (l > r) localNewer = true;
    if (r > l) remoteNewer = true;
  }
  return localNewer && remoteNewer;
}
