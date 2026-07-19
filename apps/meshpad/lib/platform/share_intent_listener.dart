import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/meshpad_status_hint.dart';
import '../core/ui/status_hint_provider.dart';
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

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener>
    with WidgetsBindingObserver {
  StreamSubscription<SharePayload>? _subscription;
  String? _lastFingerprint;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handleInitialShare());
        _subscription = ShareIntentPlatform.shareStream.listen(_handleShare);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (kIsWeb || !Platform.isAndroid) return;
    unawaited(_onResumed());
  }

  Future<void> _onResumed() async {
    await _handleInitialShare();
    try {
      await ref.read(notesListProvider.notifier).reload();
    } catch (_) {
      // Provider may not be ready yet during early resume.
    }
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

  String _fingerprint(SharePayload payload) {
    if (payload.isText) {
      return 'text:${payload.text?.trim() ?? ''}';
    }
    final paths = payload.resolvedFilePaths.toList()..sort();
    return 'files:${paths.join('|')}';
  }

  bool _isDuplicate(SharePayload payload) {
    final fp = _fingerprint(payload);
    final at = _lastHandledAt;
    if (at != null &&
        fp == _lastFingerprint &&
        DateTime.now().difference(at) < const Duration(seconds: 5)) {
      return true;
    }
    _lastFingerprint = fp;
    _lastHandledAt = DateTime.now();
    return false;
  }

  Future<void> _handleShare(SharePayload payload) async {
    if (_isDuplicate(payload)) return;

    final notifier = ref.read(notesListProvider.notifier);

    if (payload.isText &&
        payload.text != null &&
        payload.text!.trim().isNotEmpty) {
      final raw = payload.text!.trim();
      final markdown = _markdownFromSharedText(raw);
      await notifier.createNote(markdown: markdown);
      _showSnack('Заметка создана из текста');
      return;
    }

    if (payload.isFile || payload.isFiles) {
      final paths = <String>[];
      for (final path in payload.resolvedFilePaths) {
        if (await File(path).exists()) paths.add(path);
      }
      if (paths.isEmpty) return;

      await notifier.createNote(
        markdown: '',
        attachmentPaths: paths,
      );
      _showSnack(
        paths.length == 1
            ? 'Заметка создана из файла'
            : 'Заметка создана из ${paths.length} файлов',
      );
    }
  }

  String _markdownFromSharedText(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return '[$raw]($raw)';
    }
    return raw;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    showMeshPadHint(context, message, severity: StatusHintSeverity.success);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
