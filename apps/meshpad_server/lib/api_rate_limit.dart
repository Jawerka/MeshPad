import 'dart:io';

import 'package:shelf/shelf.dart';

/// Default API rate limit (PLAN §11.2.4).
const apiRateLimitPerMinute = 120;

/// Sliding-window limiter keyed by client IP (in-memory; single server process).
class ApiRateLimiter {
  ApiRateLimiter({this.maxPerMinute = apiRateLimitPerMinute});

  final int maxPerMinute;
  final Map<String, List<DateTime>> _hits = {};

  bool allow(String clientKey) {
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(minutes: 1));
    final hits = _hits.putIfAbsent(clientKey, () => <DateTime>[]);
    hits.removeWhere((t) => t.isBefore(windowStart));
    if (hits.length >= maxPerMinute) return false;
    hits.add(now);
    return true;
  }
}

String apiClientKey(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.trim().isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    return info.remoteAddress.address;
  }
  return 'unknown';
}

bool _isRateLimitExempt(Request request) {
  final path = request.url.path;
  if (path == 'api/health') return true;
  if (request.method == 'OPTIONS') return true;
  return false;
}

Middleware apiRateLimitMiddleware({
  ApiRateLimiter? limiter,
}) {
  final gate = limiter ?? ApiRateLimiter();
  return (Handler inner) {
    return (Request request) async {
      if (!_isRateLimitExempt(request)) {
        final key = apiClientKey(request);
        if (!gate.allow(key)) {
          return Response(
            429,
            body: '{"error":"rate_limited"}',
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      }
      return inner(request);
    };
  };
}
