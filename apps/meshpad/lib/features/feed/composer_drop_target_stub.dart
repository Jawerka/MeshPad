import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ComposerDropTarget extends StatelessWidget {
  const ComposerDropTarget({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.enabled = true,
  });

  final Widget child;
  final void Function(List<PlatformFile> files) onFilesDropped;
  final bool enabled;

  static bool get isSupported => false;

  @override
  Widget build(BuildContext context) => child;
}
