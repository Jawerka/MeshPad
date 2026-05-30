import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showImageLightbox(
  BuildContext context,
  List<String> imagePaths, {
  int initialIndex = 0,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _LightboxDialog(
      imagePaths: imagePaths,
      initialIndex: initialIndex,
    ),
  );
}

class _LightboxDialog extends StatefulWidget {
  const _LightboxDialog({
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imagePaths.length > 1;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _PrevIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NextIntent(),
      },
      child: Actions(
        actions: {
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
          _PrevIntent: CallbackAction<_PrevIntent>(
            onInvoke: (_) {
              if (_index > 0) {
                _controller.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) {
              if (_index < widget.imagePaths.length - 1) {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.imagePaths.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        File(widget.imagePaths[index]),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              if (hasMultiple) ...[
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _index > 0 ? Colors.white : Colors.white24,
                      size: 36,
                    ),
                    onPressed: _index > 0
                        ? () => _controller.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            )
                        : null,
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _index < widget.imagePaths.length - 1
                          ? Colors.white
                          : Colors.white24,
                      size: 36,
                    ),
                    onPressed: _index < widget.imagePaths.length - 1
                        ? () => _controller.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.imagePaths.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}
