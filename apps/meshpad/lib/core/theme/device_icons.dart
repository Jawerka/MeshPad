import 'package:flutter/material.dart';

/// Preset device icons (PLAN §4.3).
const kDeviceIconIds = [
  'laptop',
  'phone',
  'tablet',
  'desktop',
  'server',
  'device',
];

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
      'desktop' => Icons.computer,
      'server' => Icons.dns_outlined,
      _ => Icons.devices_other,
    };

String normalizeDeviceIcon(String icon) =>
    kDeviceIconIds.contains(icon) ? icon : 'device';

/// Modal grid to pick a preset device icon; returns chosen id or null.
Future<String?> showDeviceIconPicker(
  BuildContext context, {
  required String currentIcon,
  required Color accent,
}) {
  final selected = normalizeDeviceIcon(currentIcon);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Иконка устройства'),
      content: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final id in kDeviceIconIds)
            IconButton(
              tooltip: id,
              isSelected: id == selected,
              selectedIcon: Icon(peerIconFor(id), color: accent),
              icon: Icon(peerIconFor(id)),
              style: IconButton.styleFrom(
                backgroundColor: id == selected
                    ? accent.withValues(alpha: 0.18)
                    : null,
              ),
              onPressed: () => Navigator.pop(context, id),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );
}
