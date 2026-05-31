/// Derives a display title from [markdown] (first ATX heading or first line).
String titleFromMarkdown(String markdown) {
  for (final line in markdown.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final heading = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      return _cleanInlineTitle(heading.group(1)!);
    }
    return _cleanInlineTitle(trimmed);
  }
  return '';
}

/// Picks note title: explicit override, derived from markdown, or [currentTitle].
String resolveNoteTitle({
  required String currentTitle,
  required String markdown,
  String? explicitTitle,
}) {
  if (explicitTitle != null) return explicitTitle;
  final derived = titleFromMarkdown(markdown);
  if (derived.isNotEmpty) return derived;
  return currentTitle;
}

String _cleanInlineTitle(String raw) {
  var text = raw.replaceAll(RegExp(r'[*_`~\[\]]'), '').trim();
  if (text.length > 120) {
    text = '${text.substring(0, 120)}…';
  }
  return text;
}
