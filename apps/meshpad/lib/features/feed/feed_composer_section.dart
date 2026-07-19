import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/services/notes_service.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'composer_drop_target.dart';

class FeedComposerSection extends ConsumerStatefulWidget {
  const FeedComposerSection({super.key, required this.focusNode});

  final FocusNode focusNode;

  @override
  ConsumerState<FeedComposerSection> createState() =>
      _FeedComposerSectionState();
}

class _FeedComposerSectionState extends ConsumerState<FeedComposerSection> {
  final _bodyController = TextEditingController();
  final _pendingFiles = <PlatformFile>[];
  var _saving = false;
  AttachmentCopyProgress? _copyProgress;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    _addPendingFiles(result.files);
  }

  void _addPendingFiles(List<PlatformFile> incoming) {
    setState(() {
      for (final file in incoming) {
        if (kIsWeb && file.bytes == null) continue;
        if (!kIsWeb && file.path == null) continue;
        final duplicate = _pendingFiles.any(
          (existing) =>
              existing.name == file.name && existing.size == file.size,
        );
        if (!duplicate) _pendingFiles.add(file);
      }
    });
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _pendingFiles.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _copyProgress = null;
    });
    try {
      await ref.read(notesListProvider.notifier).createNote(
            markdown: body,
            attachmentPaths: kIsWeb
                ? const []
                : _pendingFiles.map((file) => file.path!).toList(),
            attachmentBytes: kIsWeb
                ? [
                    for (final file in _pendingFiles)
                      NoteAttachmentBytes(
                        name: file.name,
                        bytes: file.bytes!,
                      ),
                  ]
                : const [],
            onAttachmentProgress: _pendingFiles.isEmpty
                ? null
                : (progress) {
                    if (mounted) setState(() => _copyProgress = progress);
                  },
          );
      _bodyController.clear();
      setState(() {
        _pendingFiles.clear();
        _copyProgress = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _copyProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactFeedLayout(context);
    final composer = _buildComposer(context);
    return ComposerDropTarget(
      enabled: !_saving,
      onFilesDropped: _addPendingFiles,
      child: Container(
        padding:
            EdgeInsets.fromLTRB(compact ? 8 : 16, 12, compact ? 8 : 16, 16),
        decoration: BoxDecoration(
          color: MeshPadColors.backgroundElevated,
          border: Border(top: BorderSide(color: MeshPadColors.border)),
        ),
        child: compact
            ? composer
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MeshPadColors.composerMaxWidth,
                  ),
                  child: composer,
                ),
              ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_copyProgress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _copyProgress!.fileCount > 1
                      ? 'Копирование ${_copyProgress!.fileName} '
                          '(${_copyProgress!.fileIndex}/${_copyProgress!.fileCount})'
                      : 'Копирование ${_copyProgress!.fileName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MeshPadColors.textMuted,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _copyProgress!.isIndeterminate
                      ? null
                      : _copyProgress!.fraction,
                  minHeight: 3,
                ),
              ],
            ),
          ),
        if (_pendingFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in _pendingFiles)
                  FeedPendingAttachmentChip(
                    name: file.name,
                    onRemove: () => setState(() => _pendingFiles.remove(file)),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _saving ? null : _pickAttachments,
              icon: const Icon(Icons.attach_file),
              tooltip: 'Прикрепить файл',
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                      HardwareKeyboard.instance.isControlPressed &&
                      !_saving) {
                    unawaited(_submit());
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  focusNode: widget.focusNode,
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 10,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class FeedPendingAttachmentChip extends StatelessWidget {
  const FeedPendingAttachmentChip({
    super.key,
    required this.name,
    required this.onRemove,
  });

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final attachment = AttachmentMeta(
      name: name,
      size: 0,
      mime: mimeFromFileName(name),
    );
    final kind = attachmentPreviewKind(attachment);
    final icon = switch (kind) {
      AttachmentPreviewKind.image => Icons.image_outlined,
      AttachmentPreviewKind.video => Icons.videocam_outlined,
      AttachmentPreviewKind.audio => Icons.audiotrack_outlined,
      AttachmentPreviewKind.file => Icons.insert_drive_file,
    };

    return InputChip(
      label: Text(name, overflow: TextOverflow.ellipsis),
      avatar: Icon(icon, size: 18),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
    );
  }
}
