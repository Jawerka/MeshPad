import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'lightbox_image.dart';
import 'media_viewer_top_bar.dart';

Future<void> showImageLightbox(
  BuildContext context,
  List<String> imageSources, {
  int initialIndex = 0,
  List<String>? fileNames,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _LightboxDialog(
      imageSources: imageSources,
      fileNames: fileNames,
      initialIndex: initialIndex,
    ),
  );
}

class _LightboxDialog extends StatefulWidget {
  const _LightboxDialog({
    required this.imageSources,
    required this.initialIndex,
    this.fileNames,
  });

  final List<String> imageSources;
  final List<String>? fileNames;
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
    _index = widget.initialIndex.clamp(0, widget.imageSources.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.imageSources.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _fileNameFor(int index) {
    final names = widget.fileNames;
    if (names != null && index >= 0 && index < names.length) {
      final name = names[index].trim();
      if (name.isNotEmpty) return name;
    }
    final source = widget.imageSources[index];
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final segment = Uri.parse(source).pathSegments;
      if (segment.isNotEmpty) return segment.last;
    }
    return p.basename(source);
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imageSources.length > 1;
    final source = widget.imageSources[_index];
    final fileName = _fileNameFor(_index);

    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.imageSources.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, index) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: InteractiveViewer(
                      child: buildLightboxImage(widget.imageSources[index]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: MediaViewerTopBar(
            title: fileName,
            source: source,
            fileName: fileName,
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
              onPressed: _index > 0 ? () => _goTo(-1) : null,
            ),
          ),
          Positioned(
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: _index < widget.imageSources.length - 1
                    ? Colors.white
                    : Colors.white24,
                size: 36,
              ),
              onPressed: _index < widget.imageSources.length - 1
                  ? () => _goTo(1)
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
                '${_index + 1} / ${widget.imageSources.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
