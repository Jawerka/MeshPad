import 'package:connectivity_plus/connectivity_plus.dart';

/// True when connectivity includes a LAN-capable transport (Wi‑Fi, ethernet, VPN).
bool hasLanTransport(List<ConnectivityResult> results) {
  return results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn,
  );
}
