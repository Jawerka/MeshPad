import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/notes_providers.dart';
import 'share_intent.dart';

/// Handles Android share-to intents and creates notes from shared content.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<SharePayload>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialShare();
        _subscription = ShareIntentPlatform.shareStream.listen(_handleShare);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _handleInitialShare() async {
    try {
      final payload = await ShareIntentPlatform.getInitialShare();
      if (payload != null) {
        await _handleShare(payload);
      }
    } catch (_) {
      // Share channel unavailable outside Android.
    }
  }

  Future<void> _handleShare(SharePayload payload) async {
    final notifier = ref.read(notesListProvider.notifier);

    if (payload.isText && payload.text != null && payload.text!.trim().isNotEmpty) {
      await notifier.createNote(markdown: payload.text!.trim());
      _showSnack('Заметка создана из текста');
      return;
    }

    if (payload.isFile &&
        payload.filePath != null &&
        await File(payload.filePath!).exists()) {
      await notifier.createNote(
        markdown: '',
        attachmentPaths: [payload.filePath!],
      );
      _showSnack('Заметка создана из файла');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
