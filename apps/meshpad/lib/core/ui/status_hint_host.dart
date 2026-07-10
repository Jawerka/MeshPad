import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_hint_provider.dart';

class StatusHintHost extends ConsumerWidget {
  const StatusHintHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = ref.watch(statusHintProvider);
    if (hint == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tooltipTheme = theme.tooltipTheme;
    final decoration = tooltipTheme.decoration ??
        BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        );
    final textStyle = tooltipTheme.textStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onInverseSurface,
        );

    final icon = switch (hint.severity) {
      StatusHintSeverity.success => Icons.check_circle_outline,
      StatusHintSeverity.error => Icons.error_outline,
      StatusHintSeverity.info => Icons.info_outline,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(hint.message),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () => ref.read(statusHintProvider.notifier).dismiss(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: decoration is BoxDecoration
                    ? decoration
                    : BoxDecoration(
                        color: theme.colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                child: Padding(
                  padding: tooltipTheme.padding ??
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: textStyle?.color ??
                            theme.colorScheme.onInverseSurface,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hint.message,
                          style: textStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
