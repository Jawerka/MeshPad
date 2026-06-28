import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads current Wi‑Fi SSID (Android only; null elsewhere).
class WifiInfoPlatform {
  WifiInfoPlatform._();

  static const _channel = MethodChannel('com.meshpad/wifi');

  static Future<String?> currentSsid() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<String>('getCurrentSsid');
      if (raw == null || raw.isEmpty) return null;
      return raw.replaceAll('"', '');
    } on PlatformException {
      return null;
    }
  }
}
