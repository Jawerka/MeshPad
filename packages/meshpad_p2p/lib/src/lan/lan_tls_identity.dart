import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Self-signed TLS identity for LAN sync (Phase B.4).
class LanTlsIdentity {
  LanTlsIdentity._({
    required this.securityContext,
    required this.certPem,
    required this.keyPem,
    required this.certSha256Hex,
  });

  final SecurityContext securityContext;
  final String certPem;
  final String keyPem;
  final String certSha256Hex;

  static const certFileName = 'server.crt';
  static const keyFileName = 'server.key';

  static Future<LanTlsIdentity> loadOrCreate(Directory tlsDir) async {
    await tlsDir.create(recursive: true);
    final certFile = File(p.join(tlsDir.path, certFileName));
    final keyFile = File(p.join(tlsDir.path, keyFileName));
    if (await certFile.exists() && await keyFile.exists()) {
      return _fromPem(
        await certFile.readAsString(),
        await keyFile.readAsString(),
      );
    }

    final generated = _generate();
    await certFile.writeAsString(generated.certPem);
    await keyFile.writeAsString(generated.keyPem);
    return generated;
  }

  static LanTlsIdentity _fromPem(String certPem, String keyPem) {
    final context = SecurityContext();
    context.useCertificateChainBytes(utf8.encode(certPem));
    context.usePrivateKeyBytes(utf8.encode(keyPem));
    return LanTlsIdentity._(
      securityContext: context,
      certPem: certPem,
      keyPem: keyPem,
      certSha256Hex: sha256HexFromCertPem(certPem),
    );
  }

  static LanTlsIdentity _generate() {
    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;
    const dn = {'CN': 'MeshPad'};
    final csr = X509Utils.generateRsaCsrPem(
      dn,
      privateKey,
      publicKey,
      san: const ['localhost', '127.0.0.1'],
    );
    final certPem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      3650,
      sans: const ['localhost', '127.0.0.1'],
      extKeyUsage: [ExtendedKeyUsage.SERVER_AUTH],
    );
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
    return _fromPem(certPem, keyPem);
  }

  static String sha256HexFromCertPem(String certPem) {
    final der = CryptoUtils.getBytesFromPEMString(certPem);
    return _bytesToHex(sha256.convert(der).bytes);
  }

  static String sha256HexFromX509(X509Certificate cert) =>
      _bytesToHex(sha256.convert(cert.der).bytes);

  static HttpClient createPinnedHttpClient({
    String? expectedSha256Hex,
    bool allowUnpinned = false,
  }) {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
    client.badCertificateCallback = (cert, host, port) {
      if (expectedSha256Hex != null) {
        return sha256HexFromX509(cert) == expectedSha256Hex.toLowerCase();
      }
      return allowUnpinned;
    };
    return client;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
