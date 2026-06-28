import 'pairing_protocol.dart';

/// LAN PIN pairing payload encoded in a QR code (PLAN §11.4.3).
///
/// Format: `meshpad://pair?host=<lan-ip>&port=<http>&pin=<6-digit>[&tls=<tls-port>]`
class PairingQrPayload {
  const PairingQrPayload({
    required this.host,
    required this.httpPort,
    required this.pin,
    this.tlsPort,
  });

  static const scheme = 'meshpad';
  static const authority = 'pair';

  final String host;
  final int httpPort;
  final String pin;
  final int? tlsPort;

  /// Encoded URI string for [QrImageView] / mobile scanner.
  String encode() {
    final uri = Uri(
      scheme: scheme,
      host: authority,
      queryParameters: {
        'host': host,
        'port': '$httpPort',
        'pin': pin,
        if (tlsPort != null) 'tls': '$tlsPort',
      },
    );
    return uri.toString();
  }

  static PairingQrPayload? tryDecode(String raw) {
    try {
      return decode(raw);
    } on FormatException {
      return null;
    }
  }

  static PairingQrPayload decode(String raw) {
    final uri = Uri.parse(raw.trim());
    if (uri.scheme != scheme) {
      throw const FormatException('invalid scheme');
    }
    if (uri.host != authority) {
      throw const FormatException('invalid authority');
    }

    final host = uri.queryParameters['host']?.trim();
    if (host == null || host.isEmpty) {
      throw const FormatException('host required');
    }

    final portRaw = uri.queryParameters['port']?.trim();
    final httpPort = int.tryParse(portRaw ?? '');
    if (httpPort == null || httpPort <= 0 || httpPort > 65535) {
      throw const FormatException('invalid port');
    }

    final pin = uri.queryParameters['pin']?.trim() ?? '';
    if (!isValidPairingPin(pin)) {
      throw const FormatException('invalid pin');
    }

    final tlsRaw = uri.queryParameters['tls']?.trim();
    int? tlsPort;
    if (tlsRaw != null && tlsRaw.isNotEmpty) {
      tlsPort = int.tryParse(tlsRaw);
      if (tlsPort == null || tlsPort <= 0 || tlsPort > 65535) {
        throw const FormatException('invalid tls port');
      }
    }

    return PairingQrPayload(
      host: host,
      httpPort: httpPort,
      pin: pin,
      tlsPort: tlsPort,
    );
  }
}
