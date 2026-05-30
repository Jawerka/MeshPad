import 'package:flutter/material.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/theme/meshpad_colors.dart';
import 'attachment_thumbnail.dart';
import 'lightbox.dart';

class AttachmentGrid extends StatelessWidget {
  const AttachmentGrid({
    super.key,
    required this.note,
    this.dataDir,
    this.attachmentUriBuilder,
    this.onTapImage,
  });

  final Note note;
  final String? dataDir;
  final Uri? Function(AttachmentMeta attachment)? attachmentUriBuilder;
  final void Function(int index, List<AttachmentMeta> images)? onTapImage;

  @override
  Widget build(BuildContext context) {
    if (note.attachments.isEmpty) return const SizedBox.shrink();

    final images = note.attachments.where(isImageAttachment).toList();
    final files = note.attachments.where((a) => !isImageAttachment(a)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < images.length; i++)
                _ImageTile(
                  image: _imageSource(note, images[i]),
                  onTap: () {
                    if (onTapImage != null) {
                      onTapImage!(i, images);
                    } else {
                      showImageLightbox(
                        context,
                        [
                          for (final image in images)
                            _imageSource(note, image).lightboxSource,
                        ],
                        initialIndex: i,
                      );
                    }
                  },
                ),
            ],
          ),
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...files.map(
            (file) => _FileChip(
              name: file.name,
              size: file.size,
            ),
          ),
        ],
      ],
    );
  }

  _ImageSource _imageSource(Note note, AttachmentMeta attachment) {
    final remote = attachmentUriBuilder?.call(attachment);
    if (remote != null) {
      return _ImageSource.network(remote.toString());
    }
    final dir = dataDir;
    if (dir != null) {
      return _ImageSource.file(noteAttachmentPath(note, attachment, dir));
    }
    return const _ImageSource.missing();
  }
}

class _ImageSource {
  const _ImageSource.file(this.path) : url = null, missing = false;

  const _ImageSource.network(this.url) : path = null, missing = false;

  const _ImageSource.missing() : path = null, url = null, missing = true;

  final String? path;
  final String? url;
  final bool missing;

  String get lightboxSource => url ?? path ?? '';
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.image, required this.onTap});

  final _ImageSource image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (image.missing) {
      return _errorBox();
    }
    return buildAttachmentThumbnail(
      path: image.path,
      url: image.url,
      errorBox: _errorBox(),
    );
  }

  Widget _errorBox() {
    return Container(
      width: 120,
      height: 120,
      color: MeshPadColors.backgroundElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name, required this.size});

  final String name;
  final int size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 16, color: MeshPadColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$name · ${_formatSize(size)}',
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

String noteAttachmentPath(Note note, AttachmentMeta attachment, String dataDir) {
  return MeshPadPaths(dataDir).attachmentFile(note.id, attachment.name);
}
