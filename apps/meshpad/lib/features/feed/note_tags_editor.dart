import 'package:flutter/material.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';

Future<List<String>?> showNoteTagsEditorDialog(
  BuildContext context, {
  required List<String> initialTags,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _NoteTagsEditorDialog(initialTags: initialTags),
  );
}

class _NoteTagsEditorDialog extends StatefulWidget {
  const _NoteTagsEditorDialog({required this.initialTags});

  final List<String> initialTags;

  @override
  State<_NoteTagsEditorDialog> createState() => _NoteTagsEditorDialogState();
}

class _NoteTagsEditorDialogState extends State<_NoteTagsEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatTagsInput(widget.initialTags),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.noteTagsTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.noteTagsLabel,
          hintText: l10n.noteTagsHint,
        ),
        textCapitalization: TextCapitalization.none,
        onSubmitted: (_) => _save(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    Navigator.pop(context, parseTagsInput(_controller.text));
  }
}
