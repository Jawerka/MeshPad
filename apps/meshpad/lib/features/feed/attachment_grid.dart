import 'package:flutter/material.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/theme/meshpad_colors.dart';
import 'attachment_media_source.dart';
import 'attachment_thumbnail.dart';
import 'lightbox.dart';
import 'media_attachment_preview.dart';

class AttachmentGrid extends StatelessWidget {
  const AttachmentGrid({
    super.key,
    required this.note,
    this.dataDir,
    this.attachmentUriBuilder,
    this.attachmentThumbUriBuilder,
    this.onTapImage,
    this.onOpenAttachment,
  });

  final Note note;
  final String? dataDir;
  final Uri? Function(AttachmentMeta attachment)? attachmentUriBuilder;
  final Uri? Function(AttachmentMeta attachment)? attachmentThumbUriBuilder;
  final void Function(int index, List<AttachmentMeta> images)? onTapImage;
  final Future<void> Function(AttachmentMeta attachment)? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    if (note.attachments.isEmpty) return const SizedBox.shrink();

    final images = note.attachments.where(isImageAttachment).toList();
    final videos = note.attachments.where(isVideoAttachment).toList();
    final audios = note.attachments.where(isAudioAttachment).toList();
    final files = note.attachments
        .where(
          (attachment) =>
              !isImageAttachment(attachment) &&
              !isVideoAttachment(attachment) &&
              !isAudioAttachment(attachment),
        )
        .toList();

    Future<void> openAttachment(AttachmentMeta attachment) async {
      if (onOpenAttachment == null) return;
      await onOpenAttachment!(attachment);
    }

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
                  source: _mediaSource(note, images[i]),
                  onTap: () {
                    if (onTapImage != null) {
                      onTapImage!(i, images);
                    } else {
                      showImageLightbox(
                        context,
                        [
                          for (final image in images)
                            _mediaSource(note, image).primary,
                        ],
                        fileNames: [for (final image in images) image.name],
                        initialIndex: i,
                      );
                    }
                  },
                ),
            ],
          ),
        ],
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...videos.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VideoAttachmentPreview(
                attachment: attachment,
                source: _mediaSource(note, attachment),
                onOpenExternally: onOpenAttachment == null
                    ? null
                    : () => openAttachment(attachment),
              ),
            ),
          ),
        ],
        if (audios.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...audios.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AudioAttachmentPreview(
                attachment: attachment,
                source: _mediaSource(note, attachment),
                onOpenExternally: onOpenAttachment == null
                    ? null
                    : () => openAttachment(attachment),
              ),
            ),
          ),
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...files.map(
            (file) => _FileChip(
              name: file.name,
              size: file.size,
              onTap:
                  onOpenAttachment == null ? null : () => openAttachment(file),
            ),
          ),
        ],
      ],
    );
  }

  AttachmentMediaSource _mediaSource(Note note, AttachmentMeta attachment) {
    return resolveAttachmentMediaSource(
      note: note,
      attachment: attachment,
      dataDir: dataDir,
      attachmentUriBuilder: attachmentUriBuilder,
      attachmentThumbUriBuilder: attachmentThumbUriBuilder,
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.source, required this.onTap});

  final AttachmentMediaSource source;
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
    if (source.missing) {
      return _errorBox();
    }
    return buildAttachmentThumbnail(
      path: source.path,
      thumbPath: source.thumbPath,
      url: source.url,
      thumbUrl: source.thumbUrl,
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
  const _FileChip({
    required this.name,
    required this.size,
    this.onTap,
  });

  final String name;
  final int size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = '$name · ${_formatSize(size)}';
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: onTap == null ? null : MeshPadColors.primary,
          decoration: onTap == null ? null : TextDecoration.underline,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.save_alt_outlined,
                size: 16,
                color: onTap == null
                    ? MeshPadColors.textMuted
                    : MeshPadColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: style,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
