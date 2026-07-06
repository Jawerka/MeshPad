import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class LocalDeviceActions extends StatelessWidget {
  const LocalDeviceActions({
    super.key,
    required this.compact,
    required this.onPickIcon,
    required this.onRename,
    required this.onSync,
  });

  final bool compact;
  final VoidCallback onPickIcon;
  final VoidCallback onRename;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (compact) {
      return DeviceActionsMenu(
        items: [
          (
            value: 'icon',
            label: l10n.devicesActionIcon,
            icon: Icons.palette_outlined
          ),
          (
            value: 'rename',
            label: l10n.devicesActionRename,
            icon: Icons.edit_outlined
          ),
          (value: 'sync', label: l10n.devicesActionSync, icon: Icons.sync),
        ],
        onSelected: (value) {
          switch (value) {
            case 'icon':
              onPickIcon();
            case 'rename':
              onRename();
            case 'sync':
              onSync();
          }
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: l10n.devicesActionIcon,
          onPressed: onPickIcon,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.devicesActionRename,
          onPressed: onRename,
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: l10n.devicesActionSync,
          onPressed: onSync,
        ),
      ],
    );
  }
}

class TrustedDeviceActions extends StatelessWidget {
  const TrustedDeviceActions({
    super.key,
    required this.compact,
    required this.onPickIcon,
    required this.onRename,
    required this.onSync,
    required this.onRevoke,
  });

  final bool compact;
  final VoidCallback onPickIcon;
  final VoidCallback onRename;
  final VoidCallback onSync;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (compact) {
      return DeviceActionsMenu(
        items: [
          (
            value: 'icon',
            label: l10n.devicesActionIcon,
            icon: Icons.palette_outlined
          ),
          (
            value: 'rename',
            label: l10n.devicesActionRename,
            icon: Icons.edit_outlined
          ),
          (value: 'sync', label: l10n.devicesActionSync, icon: Icons.sync),
          (
            value: 'revoke',
            label: l10n.devicesActionRevoke,
            icon: Icons.link_off_outlined,
          ),
        ],
        onSelected: (value) {
          switch (value) {
            case 'icon':
              onPickIcon();
            case 'rename':
              onRename();
            case 'sync':
              onSync();
            case 'revoke':
              onRevoke();
          }
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: l10n.devicesActionIcon,
          onPressed: onPickIcon,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.devicesActionRename,
          onPressed: onRename,
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: l10n.devicesActionSync,
          onPressed: onSync,
        ),
        IconButton(
          icon: const Icon(Icons.link_off_outlined),
          tooltip: l10n.devicesActionRevoke,
          onPressed: onRevoke,
        ),
      ],
    );
  }
}

class DeviceActionsMenu extends StatelessWidget {
  const DeviceActionsMenu({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<({String value, String label, IconData icon})> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.devicesActionsTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.value,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.icon, size: 22),
              title: Text(item.label),
            ),
          ),
      ],
    );
  }
}
