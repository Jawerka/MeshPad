import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Shows a QR code for the host device during PIN pairing (PLAN §11.4.3).
class PairingQrCodeView extends StatelessWidget {
  const PairingQrCodeView({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.pairingQrHostHint,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 200,
              gapless: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen QR scanner; returns decoded [PairingQrPayload] on success.
Future<PairingQrPayload?> showPairingQrScanner(BuildContext context) {
  return Navigator.of(context).push<PairingQrPayload>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => const _PairingQrScannerPage(),
    ),
  );
}

class _PairingQrScannerPage extends StatefulWidget {
  const _PairingQrScannerPage();

  @override
  State<_PairingQrScannerPage> createState() => _PairingQrScannerPageState();
}

class _PairingQrScannerPageState extends State<_PairingQrScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  var _handled = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final payload = PairingQrPayload.tryDecode(raw);
      if (payload == null) continue;
      _handled = true;
      Navigator.of(context).pop(payload);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairingScanQr),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.pairingQrScanHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      shadows: const [Shadow(blurRadius: 8)],
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
