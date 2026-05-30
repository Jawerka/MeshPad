import 'package:flutter/material.dart';

/// Stable accent color for a device peer id (PLAN §4.3).
Color peerAccentColor(String peerId) {
  final hash = peerId.hashCode;
  final hue = (hash.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.52).toColor();
}

IconData peerIconFor(String icon) => switch (icon) {
      'phone' => Icons.smartphone,
      'tablet' => Icons.tablet,
      'laptop' => Icons.laptop,
      _ => Icons.devices_other,
    };
