import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'attachment_media_source.dart';
import 'media_viewer_top_bar.dart';

/// Fraction of video duration used for feed poster frame (desktop).
const videoPosterTimeFraction = 1 / 3;

bool useVideoPosterInFeed() =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux);

class VideoAttachmentPreview extends StatelessWidget {
  const VideoAttachmentPreview({
    super.key,
    required this.attachment,
    required this.source,
    this.onOpenExternally,
  });

  final AttachmentMeta attachment;
  final AttachmentMediaSource source;
  final VoidCallback? onOpenExternally;

  @override
  Widget build(BuildContext context) {
    if (useVideoPosterInFeed()) {
      return _VideoPosterPreview(
        attachment: attachment,
        source: source,
        onOpenExternally: onOpenExternally,
      );
    }
    return _VideoInlinePreview(
      attachment: attachment,
      source: source,
      onOpenExternally: onOpenExternally,
    );
  }
}

/// Desktop: paused frame at [videoPosterTimeFraction], tap opens player dialog.
class _VideoPosterPreview extends StatefulWidget {
  const _VideoPosterPreview({
    required this.attachment,
    required this.source,
    this.onOpenExternally,
  });

  final AttachmentMeta attachment;
  final AttachmentMediaSource source;
  final VoidCallback? onOpenExternally;

  @override
  State<_VideoPosterPreview> createState() => _VideoPosterPreviewState();
}

class _VideoPosterPreviewState extends State<_VideoPosterPreview> {
  VideoPlayerController? _controller;
  var _failed = false;
  var _posterReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPoster());
  }

  @override
  void didUpdateWidget(covariant _VideoPosterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.primary != widget.source.primary) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _posterReady = false;
      unawaited(_loadPoster());
    }
  }

  Future<void> _loadPoster() async {
    if (!widget.source.isAvailable) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = _createController(widget.source.primary);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(0);

      var duration = controller.value.duration;
      if (duration.inMilliseconds <= 0) {
        await controller.play();
        for (var i = 0; i < 30 && duration.inMilliseconds <= 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          duration = controller.value.duration;
        }
        await controller.pause();
      }

      final seekMs = duration.inMilliseconds > 0
          ? (duration.inMilliseconds * videoPosterTimeFraction).round()
          : 0;
      final seekTarget = Duration(milliseconds: seekMs);

      await controller.seekTo(seekTarget);
      await controller.play();
      for (var i = 0; i < 40; i++) {
        if (!controller.value.isBuffering &&
            controller.value.position >=
                seekTarget - const Duration(milliseconds: 500)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await controller.pause();

      if (!mounted) return;
      setState(() => _posterReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openPlayback() async {
    if (!widget.source.isAvailable) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _VideoPlaybackDialog(
        attachment: widget.attachment,
        source: widget.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = feedBubbleMaxWidth(context).clamp(200.0, 360.0);

    if (_failed || widget.source.missing) {
      return _VideoFallback(
        attachment: widget.attachment,
        maxWidth: maxWidth,
        onOpen: widget.onOpenExternally,
      );
    }

    if (!_posterReady ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return _VideoLoadingBox(maxWidth: maxWidth);
    }

    final controller = _controller!;
    final aspectRatio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return SizedBox(
      width: maxWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        child: ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return VideoPlayer(controller);
                  },
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openPlayback,
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ),
                if (widget.onOpenExternally != null ||
                    widget.source.isAvailable)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SaveMediaIconButton(
                          source: widget.source.primary,
                          fileName: widget.attachment.name,
                        ),
                        if (widget.onOpenExternally != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.open_in_new,
                              color: Colors.white70,
                            ),
                            tooltip: 'Открыть внешним приложением',
                            onPressed: widget.onOpenExternally,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile: inline player in the feed bubble.
class _VideoInlinePreview extends StatefulWidget {
  const _VideoInlinePreview({
    required this.attachment,
    required this.source,
    this.onOpenExternally,
  });

  final AttachmentMeta attachment;
  final AttachmentMediaSource source;
  final VoidCallback? onOpenExternally;

  @override
  State<_VideoInlinePreview> createState() => _VideoInlinePreviewState();
}

class _VideoInlinePreviewState extends State<_VideoInlinePreview> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _VideoInlinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.primary != widget.source.primary) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _initController();
    }
  }

  void _initController() {
    if (!widget.source.isAvailable) {
      setState(() => _failed = true);
      return;
    }

    final controller = _createController(widget.source.primary);

    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = feedBubbleMaxWidth(context).clamp(200.0, 360.0);

    if (_failed || widget.source.missing) {
      return _VideoFallback(
        attachment: widget.attachment,
        maxWidth: maxWidth,
        onOpen: widget.onOpenExternally,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _VideoLoadingBox(maxWidth: maxWidth);
    }

    final aspectRatio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return SizedBox(
      width: maxWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        child: ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePlayback,
                      child: AnimatedOpacity(
                        opacity: controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          color: Colors.black38,
                          alignment: Alignment.center,
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.onOpenExternally != null ||
                    widget.source.isAvailable)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SaveMediaIconButton(
                          source: widget.source.primary,
                          fileName: widget.attachment.name,
                        ),
                        if (widget.onOpenExternally != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.open_in_new,
                              color: Colors.white70,
                            ),
                            tooltip: 'Открыть внешним приложением',
                            onPressed: widget.onOpenExternally,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

VideoPlayerController _createController(String primary) {
  if (primary.startsWith('http://') || primary.startsWith('https://')) {
    return VideoPlayerController.networkUrl(Uri.parse(primary));
  }
  return VideoPlayerController.file(File(primary));
}

class _VideoLoadingBox extends StatelessWidget {
  const _VideoLoadingBox({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: maxWidth * 9 / 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MeshPadColors.backgroundElevated,
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _VideoPlaybackDialog extends StatefulWidget {
  const _VideoPlaybackDialog({
    required this.attachment,
    required this.source,
  });

  final AttachmentMeta attachment;
  final AttachmentMediaSource source;

  @override
  State<_VideoPlaybackDialog> createState() => _VideoPlaybackDialogState();
}

class _VideoPlaybackDialogState extends State<_VideoPlaybackDialog> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final controller = _createController(widget.source.primary);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_failed || controller == null || !controller.value.isInitialized)
            Text(
              'Не удалось воспроизвести ${widget.attachment.name}',
              style: const TextStyle(color: Colors.white70),
            )
          else
            GestureDetector(
              onTap: _togglePlayback,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MediaViewerTopBar(
              title: widget.attachment.name,
              source: widget.source.primary,
              fileName: widget.attachment.name,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({
    required this.attachment,
    required this.maxWidth,
    this.onOpen,
  });

  final AttachmentMeta attachment;
  final double maxWidth;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
      child: Container(
        width: maxWidth,
        height: maxWidth * 9 / 16,
        decoration: BoxDecoration(
          color: MeshPadColors.backgroundElevated,
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          border: Border.all(color: MeshPadColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_outlined, size: 36),
            const SizedBox(height: 8),
            Text(
              attachment.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class AudioAttachmentPreview extends StatefulWidget {
  const AudioAttachmentPreview({
    super.key,
    required this.attachment,
    required this.source,
    this.onOpenExternally,
  });

  final AttachmentMeta attachment;
  final AttachmentMediaSource source;
  final VoidCallback? onOpenExternally;

  @override
  State<AudioAttachmentPreview> createState() => _AudioAttachmentPreviewState();
}

class _AudioAttachmentPreviewState extends State<AudioAttachmentPreview> {
  final _player = AudioPlayer();
  Source? _source;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  var _playing = false;
  var _ready = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _bindPlayer();
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant AudioAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.primary != widget.source.primary) {
      _loadSource();
    }
  }

  void _bindPlayer() {
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  Future<void> _loadSource() async {
    setState(() {
      _ready = false;
      _failed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
    });

    if (!widget.source.isAvailable) {
      setState(() => _failed = true);
      return;
    }

    try {
      await _player.stop();
      final primary = widget.source.primary;
      _source = primary.startsWith('http://') || primary.startsWith('https://')
          ? UrlSource(primary)
          : DeviceFileSource(primary);
      await _player.setSource(_source!);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!_ready || _source == null) return;
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(_source!);
    }
  }

  Future<void> _seek(double value) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    await _player.seek(target);
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / _duration.inMilliseconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MeshPadColors.backgroundElevated,
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        border: Border.all(color: MeshPadColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _failed ? widget.onOpenExternally : _togglePlayback,
            icon: Icon(
              _failed
                  ? Icons.error_outline
                  : _playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
              color: MeshPadColors.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: progress.clamp(0, 1),
                    onChanged: _failed || !_ready ? null : _seek,
                  ),
                ),
                Text(
                  _failed
                      ? 'Не удалось воспроизвести'
                      : '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MeshPadColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          if (widget.onOpenExternally != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Открыть внешним приложением',
              onPressed: widget.onOpenExternally,
              icon: const Icon(Icons.open_in_new, size: 20),
            ),
        ],
      ),
    );
  }
}
