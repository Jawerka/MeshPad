import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/meshpad_colors.dart';

class ComposerDropTarget extends StatefulWidget {
  const ComposerDropTarget({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.enabled = true,
  });

  final Widget child;
  final void Function(List<PlatformFile> files) onFilesDropped;
  final bool enabled;

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  State<ComposerDropTarget> createState() => _ComposerDropTargetState();
}

class _ComposerDropTargetState extends State<ComposerDropTarget> {
  var _dragging = false;

  Future<void> _onDragDone(DropDoneDetails details) async {
    if (!widget.enabled) return;
    setState(() => _dragging = false);
    final files = <PlatformFile>[];
    for (final file in details.files) {
      final path = file.path;
      if (path.isEmpty) continue;
      final ioFile = File(path);
      if (!await ioFile.exists()) continue;
      files.add(
        PlatformFile(
          name: file.name,
          path: path,
          size: await ioFile.length(),
        ),
      );
    }
    if (files.isNotEmpty) widget.onFilesDropped(files);
  }

  @override
  Widget build(BuildContext context) {
    if (!ComposerDropTarget.isSupported || !widget.enabled) {
      return widget.child;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDragDone,
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MeshPadColors.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: MeshPadColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Отпустите файлы для вложения',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: MeshPadColors.primary,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
