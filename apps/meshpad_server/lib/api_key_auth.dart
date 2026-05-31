import 'dart:convert';

import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:shelf/shelf.dart';

/// Optional API key protection for headless server (PLAN §12 D.3).
class ApiKeyAuth {
  ApiKeyAuth({this.apiKey});

  final String? apiKey;

  bool get isEnabled {
    final trimmed = apiKey?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  String? get expectedKey {
    final trimmed = apiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

Middleware apiKeyAuthMiddleware(ApiKeyAuth auth) {
  return (Handler inner) {
    return (Request request) async {
      if (!auth.isEnabled) return inner(request);
      if (!request.requestedUri.path.startsWith('/api/')) {
        return inner(request);
      }
      if (isMeshPadPublicApiPath(request.requestedUri.path)) {
        return inner(request);
      }

      final provided = meshPadApiKeyFromHeaders(request.headers);
      if (!meshPadApiKeyMatches(expectedKey: auth.expectedKey, provided: provided)) {
        return Response(
          401,
          body: jsonEncode({'error': 'unauthorized'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return inner(request);
    };
  };
}
