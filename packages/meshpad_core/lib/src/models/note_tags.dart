import 'dart:convert';

const maxTagLength = 32;
const maxTagsPerNote = 20;

/// Normalizes a single tag (trim, lowercase, length limit).
String? normalizeTag(String raw) {
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > maxTagLength) {
    return trimmed.substring(0, maxTagLength);
  }
  return trimmed;
}

/// Deduplicated normalized tags preserving first-seen order.
List<String> normalizeTags(Iterable<String> raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    final tag = normalizeTag(item);
    if (tag == null || seen.contains(tag)) continue;
    seen.add(tag);
    result.add(tag);
    if (result.length >= maxTagsPerNote) break;
  }
  return result;
}

List<String> parseTagsJson(String? json) {
  if (json == null || json.trim().isEmpty || json == '[]') return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return normalizeTags(decoded.map((e) => '$e'));
  } catch (_) {
    return const [];
  }
}

String encodeTagsJson(List<String> tags) => jsonEncode(normalizeTags(tags));

/// Parses comma/space separated input from tag editor.
List<String> parseTagsInput(String input) {
  final parts = input.split(RegExp(r'[,;\s]+'));
  return normalizeTags(parts);
}

String formatTagsInput(List<String> tags) => tags.join(', ');
