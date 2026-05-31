import 'package:flutter/material.dart';

/// Text input dialog that owns its [TextEditingController] until unmount.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  String? labelText,
  String? hintText,
  String confirmLabel = 'Сохранить',
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      confirmLabel: confirmLabel,
      textCapitalization: textCapitalization,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    this.labelText,
    this.hintText,
    required this.confirmLabel,
    required this.textCapitalization,
  });

  final String title;
  final String initialValue;
  final String? labelText;
  final String? hintText;
  final String confirmLabel;
  final TextCapitalization textCapitalization;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
        textCapitalization: widget.textCapitalization,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
