Set<String> localAuthorLabels(String? displayName) {
  final labels = {'', 'Это устройство'};
  final trimmed = displayName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    labels.add(trimmed);
  }
  return labels;
}
