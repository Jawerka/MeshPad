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

/// Token being typed after the last comma/semicolon (PLAN 9.5).
String tagTokenBeforeCursor(String text, int cursorOffset) {
  final end = cursorOffset.clamp(0, text.length);
  final before = text.substring(0, end);
  final sep = before.lastIndexOf(RegExp(r'[,;]'));
  return before.substring(sep + 1).trim().toLowerCase();
}

/// Tags already committed before the cursor token.
Set<String> committedTagsBeforeCursor(String text, int cursorOffset) {
  final end = cursorOffset.clamp(0, text.length);
  final before = text.substring(0, end);
  final sep = before.lastIndexOf(RegExp(r'[,;]'));
  final completed = sep < 0 ? '' : before.substring(0, sep);
  return parseTagsInput(completed).toSet();
}

/// Autocomplete suggestions for the tag editor field.
Iterable<String> tagAutocompleteSuggestions({
  required List<String> allTags,
  required String text,
  required int cursorOffset,
  int limit = 8,
}) {
  final token = tagTokenBeforeCursor(text, cursorOffset);
  final committed = committedTagsBeforeCursor(text, cursorOffset);
  Iterable<String> candidates = allTags;
  if (token.isNotEmpty) {
    candidates = allTags.where((t) => t.startsWith(token));
  }
  return candidates.where((t) => !committed.contains(t)).take(limit);
}
