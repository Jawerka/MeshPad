/// Git `-c` arguments for GitHub HTTPS with an OAuth/PAT bearer token.
List<String> gitHttpsAuthConfigArgs(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return const [];
  return ['-c', 'http.extraheader=AUTHORIZATION: bearer $trimmed'];
}
