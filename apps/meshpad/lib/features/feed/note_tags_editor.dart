import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/providers/notes_providers.dart';
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

class _NoteTagsEditorDialog extends ConsumerStatefulWidget {
  const _NoteTagsEditorDialog({required this.initialTags});

  final List<String> initialTags;

  @override
  ConsumerState<_NoteTagsEditorDialog> createState() =>
      _NoteTagsEditorDialogState();
}

class _NoteTagsEditorDialogState extends ConsumerState<_NoteTagsEditorDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatTagsInput(widget.initialTags),
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allTags = ref.watch(distinctTagsProvider).valueOrNull ?? const [];

    return AlertDialog(
      title: Text(l10n.noteTagsTitle),
      content: SizedBox(
        width: 420,
        child: RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (value) => tagAutocompleteSuggestions(
            allTags: allTags,
            text: value.text,
            cursorOffset: value.selection.baseOffset,
          ),
          onSelected: _applySuggestion,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.noteTagsLabel,
                hintText: l10n.noteTagsHint,
              ),
              textCapitalization: TextCapitalization.none,
              onSubmitted: (_) => _save(context),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160, maxWidth: 400),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final tag = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(tag),
                        onTap: () => onSelected(tag),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
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

  void _applySuggestion(String tag) {
    final value = _controller.value;
    final text = value.text;
    final end = value.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, end);
    final after = text.substring(end);
    final sep = before.lastIndexOf(RegExp(r'[,;]'));
    final prefix = sep < 0 ? '' : before.substring(0, sep + 1);
    final spacer = prefix.isEmpty ? '' : ' ';
    final newBefore = '$prefix$spacer$tag';
    final trimmedAfter = after.trimLeft();
    final newText = trimmedAfter.isEmpty
        ? '$newBefore, '
        : '$newBefore, $trimmedAfter';
    final offset = newBefore.length + 2;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset.clamp(0, newText.length)),
    );
  }

  void _save(BuildContext context) {
    Navigator.pop(context, parseTagsInput(_controller.text));
  }
}
