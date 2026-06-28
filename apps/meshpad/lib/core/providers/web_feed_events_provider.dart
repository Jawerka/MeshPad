import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_api_client/meshpad_api_client.dart';

import 'notes_providers.dart';

/// Keeps Web feed in sync via SSE (`GET /api/events`, PLAN §11.6.1–6.2).
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
  String? _lastEventId;
  var _reconnectCount = 0;

  Future<void> start() async {
    if (_ref == null || _running) return;
    _running = true;
    unawaited(_connectLoop());
  }

  Future<void> _connectLoop() async {
    final ref = _ref;
    if (ref == null) return;

    final generation = ++_generation;
    var backoffAttempt = 0;

    while (_running && generation == _generation) {
      try {
        final baseUrl = await ref.read(webApiBaseUrlProvider.future);
        final apiKey = await ref.read(webApiKeyProvider.future);
        _client?.close();
        _client = MeshPadApiClient(baseUrl: baseUrl, apiKey: apiKey);
        await _client!.checkHealth();

        if (_reconnectCount > 0) {
          await _catchUpFeed(ref);
        }
        _reconnectCount++;

        backoffAttempt = 0;
        await for (final event in _client!.watchNoteEvents(
          lastEventId: _lastEventId,
        )) {
          if (!_running || generation != _generation) break;
          if (event.id != null) {
            _lastEventId = '${event.id}';
          }
          _scheduleReload(ref);
        }
      } catch (_) {
        // Reconnect with exponential backoff.
      }

      if (!_running || generation != _generation) break;
      backoffAttempt++;
      final seconds = math.min(60, 1 << math.min(backoffAttempt - 1, 6));
      await Future<void>.delayed(Duration(seconds: seconds));
    }
  }

  Future<void> _catchUpFeed(Ref ref) async {
    final client = _client;
    if (client != null && _lastEventId != null) {
      try {
        final since = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
        await client.listNotesUpdatedSince(since);
      } catch (_) {
        // Fall back to full reload.
      }
    }
    await ref.read(notesListProvider.notifier).reload();
    if (ref.read(feedSearchQueryProvider).trim().isNotEmpty) {
      ref.invalidate(searchResultsProvider);
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
