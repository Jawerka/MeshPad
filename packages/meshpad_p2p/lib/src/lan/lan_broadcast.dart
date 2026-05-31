import 'dart:io';

/// Broadcast targets for LAN UDP discovery (global + per-subnet /24).
Future<List<InternetAddress>> computeBroadcastTargets() async {
  final seen = <String>{};
  final targets = <InternetAddress>[];

  void add(String address) {
    if (seen.add(address)) {
      targets.add(InternetAddress(address));
    }
  }

  add('255.255.255.255');

  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final interface in interfaces) {
      if (_isVirtualInterface(interface.name)) continue;
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        if (!_isPrivateLan(ip)) continue;

        final parts = ip.split('.');
        if (parts.length != 4) continue;
        add('${parts[0]}.${parts[1]}.${parts[2]}.255');
      }
    }
  } on Object {
    // Keep global broadcast only.
  }

  return targets;
}

bool _isVirtualInterface(String name) {
  final lower = name.toLowerCase();
  return lower.contains('virtual') ||
      lower.contains('vmware') ||
      lower.contains('vbox') ||
      lower.contains('hyper-v') ||
      lower.contains('vethernet') ||
      lower.contains('docker') ||
      lower.contains('wsl');
}

bool _isPrivateLan(String ip) {
  if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
  if (!ip.startsWith('172.')) return false;
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final second = int.tryParse(parts[1]) ?? 0;
  return second >= 16 && second <= 31;
}

/// Higher score = more likely reachable on typical home Wi‑Fi (vs VPN/tunnel).
int lanHostPreferenceScore(String ip) {
  if (ip.startsWith('192.168.')) return 3;
  if (ip.startsWith('172.')) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      final second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return 2;
    }
  }
  if (ip.startsWith('10.')) return 1;
  return 0;
}

/// Picks the address most likely to work for LAN sync on the local network.
String preferredLanHost(String a, String b) {
  final scoreA = lanHostPreferenceScore(a);
  final scoreB = lanHostPreferenceScore(b);
  if (scoreA != scoreB) return scoreA > scoreB ? a : b;
  return a;
}

/// Best IPv4 from [candidates] for LAN advertisement and discovery.
String? pickPreferredLanHost(Iterable<String> candidates) {
  String? best;
  var bestScore = -1;
  for (final ip in candidates) {
    if (ip.startsWith('169.254.')) continue;
    if (!_isPrivateLan(ip)) continue;
    final score = lanHostPreferenceScore(ip);
    if (score > bestScore) {
      bestScore = score;
      best = ip;
    }
  }
  return best;
}

/// True when [host] is on the same /24 as [localHost] (typical home Wi‑Fi).
bool isSameLanSubnet(String host, String localHost) {
  final hostParts = host.split('.');
  final localParts = localHost.split('.');
  if (hostParts.length != 4 || localParts.length != 4) return false;
  return hostParts[0] == localParts[0] &&
      hostParts[1] == localParts[1] &&
      hostParts[2] == localParts[2];
}

/// Whether a stored peer address should be probed for the current local LAN.
bool shouldTryStoredLanEndpoint({
  required String storedHost,
  required String? localHost,
}) {
  if (localHost == null || localHost.isEmpty) return true;
  if (!_isPrivateLan(localHost) || !_isPrivateLan(storedHost)) return true;
  return isSameLanSubnet(storedHost, localHost);
}
