import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_api_client/meshpad_api_client.dart';

import 'notes_providers.dart';

/// Keeps Web feed in sync via SSE (`GET /api/events`, PLAN §12 D.1).
final webFeedEventsProvider = Provider<WebFeedEventsListener>((ref) {
  if (!ref.watch(isWebClientProvider)) {
    return WebFeedEventsListener.noop();
  }

  ref.watch(webApiBaseUrlProvider);
  ref.watch(webApiKeyProvider);
  final listener = WebFeedEventsListener(ref);
  ref.onDispose(listener.dispose);
  unawaited(listener.start());
  return listener;
});

class WebFeedEventsListener {
  WebFeedEventsListener(this._ref);

  WebFeedEventsListener.noop() : _ref = null;

  final Ref? _ref;
  MeshPadApiClient? _client;
  Timer? _debounce;
  var _running = false;
  var _generation = 0;

  Future<void> start() async {
    if (_ref == null || _running) return;
    _running = true;
    unawaited(_connectLoop());
  }

  Future<void> _connectLoop() async {
    final ref = _ref;
    if (ref == null) return;

    final generation = ++_generation;
    while (_running && generation == _generation) {
      try {
        final baseUrl = await ref.read(webApiBaseUrlProvider.future);
        final apiKey = await ref.read(webApiKeyProvider.future);
        _client?.close();
        _client = MeshPadApiClient(baseUrl: baseUrl, apiKey: apiKey);
        await _client!.checkHealth();

        await for (final _ in _client!.watchNoteEvents()) {
          if (!_running || generation != _generation) break;
          _scheduleReload(ref);
        }
      } catch (_) {
        // Reconnect after backoff.
      }

      if (!_running || generation != _generation) break;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  void _scheduleReload(Ref ref) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!_running) return;
      unawaited(ref.read(notesListProvider.notifier).reload());
      if (ref.read(feedSearchQueryProvider).trim().isNotEmpty) {
        ref.invalidate(searchResultsProvider);
      }
    });
  }

  void dispose() {
    _running = false;
    _generation++;
    _debounce?.cancel();
    _client?.close();
    _client = null;
  }
}
