import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads current Wi‑Fi SSID (Android only; null elsewhere).
class WifiInfoPlatform {
  WifiInfoPlatform._();

  static const _channel = MethodChannel('com.meshpad/wifi');

  /// Requests platform permission needed to read SSID on Android 10+.
  static Future<bool> ensureSsidPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('ensureWifiSsidPermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Android 10+ requires system location to be enabled for SSID reads.
  static Future<bool> isLocationEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isLocationEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> currentSsid({bool requestPermission = true}) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    if (requestPermission && !await ensureSsidPermission()) return null;
    try {
      final raw = await _channel.invokeMethod<String>('getCurrentSsid');
      return normalizeSsid(raw);
    } on PlatformException {
      return null;
    }
  }

  /// Strips quotes and rejects Android placeholder SSIDs.
  static String? normalizeSsid(String? raw) {
    if (raw == null) return null;
    final ssid = raw.replaceAll('"', '').trim();
    if (ssid.isEmpty) return null;
    final lower = ssid.toLowerCase();
    if (lower == '<unknown ssid>' || lower == 'unknown ssid') return null;
    if (lower.startsWith('0x')) return null;
    return ssid;
  }

  /// Drops Android placeholders and duplicates from a saved allow-list.
  static List<String> sanitizeAllowedWifiSsids(List<String> raw) {
    final out = <String>[];
    for (final item in raw) {
      final ssid = normalizeSsid(item);
      if (ssid != null && !out.contains(ssid)) {
        out.add(ssid);
      }
    }
    return out;
  }
}
