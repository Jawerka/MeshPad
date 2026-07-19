/// Rejects hosts that must never be persisted as a remote peer LAN address.
///
/// Loopback / link-local would make health checks hit the local process.
bool isInvalidPersistedLanHost(String? host) {
  if (host == null) return false;
  final ip = host.trim();
  if (ip.isEmpty) return true;
  if (ip == 'localhost' || ip == '::1') return true;
  if (ip.startsWith('127.')) return true;
  if (ip.startsWith('169.254.')) return true;
  return false;
}
