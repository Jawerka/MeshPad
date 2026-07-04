import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/openers/save_attachment_file.dart';
import '../../l10n/app_localizations.dart';

/// Top bar for fullscreen image/video viewers: optional title, Save, Close.
class MediaViewerTopBar extends StatelessWidget {
  const MediaViewerTopBar({
    super.key,
    this.title,
    required this.source,
    required this.fileName,
    this.onClose,
  });

  final String? title;
  final String source;
  final String fileName;
  final VoidCallback? onClose;

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await saveAttachmentFile(source: source, fileName: fileName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.fileSaved : l10n.fileSaveFailed),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGeneric(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !kIsWeb && source.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )
            else
              const Spacer(),
            if (canSave)
              TextButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.save_alt_outlined, color: Colors.white),
                label: Text(
                  l10n.save,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: l10n.close,
              onPressed: onClose ?? () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact save control for inline previews (feed bubble).
class SaveMediaIconButton extends StatelessWidget {
  const SaveMediaIconButton({
    super.key,
    required this.source,
    required this.fileName,
  });

  final String source;
  final String fileName;

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await saveAttachmentFile(source: source, fileName: fileName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.fileSaved : l10n.fileSaveFailed),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGeneric(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || source.isEmpty) return const SizedBox.shrink();

    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.save_alt_outlined, color: Colors.white70),
      tooltip: AppLocalizations.of(context).save,
      onPressed: () => _save(context),
    );
  }
}
