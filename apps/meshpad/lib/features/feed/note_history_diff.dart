import 'package:flutter/material.dart';

import '../../core/theme/meshpad_colors.dart';

enum _HistoryDiffLineKind { same, added, removed }

class _HistoryDiffLine {
  const _HistoryDiffLine(this.kind, this.text);

  final _HistoryDiffLineKind kind;
  final String text;
}

List<_HistoryDiffLine> _computeNoteHistoryLineDiff({
  required String currentMarkdown,
  required String snapshotMarkdown,
}) {
  final current = currentMarkdown.split('\n');
  final snapshot = snapshotMarkdown.split('\n');
  final m = current.length;
  final n = snapshot.length;

  // LCS table (notes are small; history preview only).
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      if (current[i] == snapshot[j]) {
        dp[i][j] = dp[i + 1][j + 1] + 1;
      } else {
        dp[i][j] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
      }
    }
  }

  final lines = <_HistoryDiffLine>[];
  var i = 0;
  var j = 0;
  while (i < m && j < n) {
    if (current[i] == snapshot[j]) {
      lines.add(_HistoryDiffLine(_HistoryDiffLineKind.same, current[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      lines.add(_HistoryDiffLine(_HistoryDiffLineKind.removed, current[i]));
      i++;
    } else {
      lines.add(_HistoryDiffLine(_HistoryDiffLineKind.added, snapshot[j]));
      j++;
    }
  }
  while (i < m) {
    lines.add(_HistoryDiffLine(_HistoryDiffLineKind.removed, current[i++]));
  }
  while (j < n) {
    lines.add(_HistoryDiffLine(_HistoryDiffLineKind.added, snapshot[j++]));
  }
  return lines;
}

/// Scrollable diff: red = removed from current, green = added from snapshot.
class NoteHistoryDiffView extends StatelessWidget {
  const NoteHistoryDiffView({
    super.key,
    required this.currentMarkdown,
    required this.snapshotMarkdown,
  });

  final String currentMarkdown;
  final String snapshotMarkdown;

  @override
  Widget build(BuildContext context) {
    final lines = _computeNoteHistoryLineDiff(
      currentMarkdown: currentMarkdown,
      snapshotMarkdown: snapshotMarkdown,
    );
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'Consolas',
          height: 1.35,
        );

    return ListView.builder(
      shrinkWrap: true,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final prefix = switch (line.kind) {
          _HistoryDiffLineKind.same => ' ',
          _HistoryDiffLineKind.added => '+',
          _HistoryDiffLineKind.removed => '-',
        };
        final bg = switch (line.kind) {
          _HistoryDiffLineKind.same => null,
          _HistoryDiffLineKind.added =>
              MeshPadColors.primary.withValues(alpha: 0.12),
          _HistoryDiffLineKind.removed => Colors.red.withValues(alpha: 0.12),
        };
        final fg = switch (line.kind) {
          _HistoryDiffLineKind.same => null,
          _HistoryDiffLineKind.added => MeshPadColors.primary,
          _HistoryDiffLineKind.removed => Colors.red.shade700,
        };
        return ColoredBox(
          color: bg ?? Colors.transparent,
          child: Text(
            '$prefix ${line.text}',
            style: mono?.copyWith(color: fg),
          ),
        );
      },
    );
  }
}
