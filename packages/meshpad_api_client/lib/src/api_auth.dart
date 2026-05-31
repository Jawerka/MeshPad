/// Header for optional MeshPad server API key (PLAN §12 D.3).
const meshPadApiKeyHeader = 'X-MeshPad-Api-Key';

/// Returns auth headers when [apiKey] is non-empty.
Map<String, String> meshPadApiKeyHeaders(String? apiKey) {
  final trimmed = apiKey?.trim();
  if (trimmed == null || trimmed.isEmpty) return const {};
  return {meshPadApiKeyHeader: trimmed};
}

/// Extracts API key from request headers (`X-MeshPad-Api-Key` or `Authorization: Bearer`).
String? meshPadApiKeyFromHeaders(Map<String, String> headers) {
  final direct = headers[meshPadApiKeyHeader.toLowerCase()];
  if (direct != null && direct.trim().isNotEmpty) {
    return direct.trim();
  }

  final auth = headers['authorization'];
  if (auth != null && auth.toLowerCase().startsWith('bearer ')) {
    final token = auth.substring(7).trim();
    if (token.isNotEmpty) return token;
  }

  return null;
}

/// Public API paths that skip API key checks.
bool isMeshPadPublicApiPath(String path) {
  final normalized = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  return normalized == '/api/health';
}

/// Validates [provided] key against configured [expectedKey].
/// When [expectedKey] is null/empty, auth is disabled and returns true.
bool meshPadApiKeyMatches({required String? expectedKey, String? provided}) {
  final expected = expectedKey?.trim();
  if (expected == null || expected.isEmpty) return true;
  return provided != null && provided == expected;
}
