import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../core/providers/discovery_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/theme/device_icons.dart';
import '../../core/theme/meshpad_colors.dart';

class DevicesSheet extends ConsumerWidget {
  const DevicesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MeshPadColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => const DevicesSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(localIdentityProvider);
    final trustedAsync = ref.watch(trustedDevicesProvider);
    final discovered = ref.watch(discoveredPeersProvider);
    final trustedIds = trustedAsync.valueOrNull?.map((d) => d.peerId).toSet() ?? {};
    final visibleDiscovered = discovered
        .where((peer) => !trustedIds.contains(peer.peerId))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MeshPadColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Устройства', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    identityAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Ошибка: $e'),
                      data: (identity) => _DeviceCard(
                        title: 'Это устройство',
                        name: identity.displayName,
                        peerId: identity.peerId,
                        icon: peerIconFor(identity.icon),
                        accent: peerAccentColor(identity.peerId),
                        trailing: IconButton(
                          icon: const Icon(Icons.sync),
                          tooltip: 'Синхронизировать',
                          onPressed: () => _runSync(context, ref),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Доверенные',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    trustedAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text('Ошибка: $e'),
                      data: (devices) {
                        if (devices.isEmpty) {
                          return Text(
                            'Нет доверенных устройств.\n'
                            'Добавьте через PIN-pairing.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: MeshPadColors.textMuted,
                                ),
                          );
                        }
                        return Column(
                          children: [
                            for (final device in devices)
                              _DeviceCard(
                                title: device.name,
                                name: device.name,
                                peerId: device.peerId,
                                icon: peerIconFor(device.icon),
                                accent: peerAccentColor(device.peerId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.link_off_outlined),
                                  tooltip: 'Отозвать доверие',
                                  onPressed: () async {
                                    final store =
                                        await ref.read(deviceStoreProvider.future);
                                    await store.revokeTrust(device.peerId);
                                    ref.invalidate(trustedDevicesProvider);
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Обнаруженные',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Демо LAN-discovery до libp2p/mDNS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MeshPadColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleDiscovered.isEmpty)
                      Text(
                        'Поиск устройств в локальной сети…',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: MeshPadColors.textMuted,
                            ),
                      )
                    else
                      Column(
                        children: [
                          for (final peer in visibleDiscovered)
                            _DeviceCard(
                              title: 'В сети',
                              name: peer.displayName,
                              peerId: peer.peerId,
                              icon: Icons.wifi_tethering,
                              accent: peerAccentColor(peer.peerId),
                              trailing: FilledButton.tonal(
                                onPressed: () => _trustDiscoveredPeer(
                                  context,
                                  ref,
                                  peer,
                                ),
                                child: const Text('Доверять'),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _showPinPairingDialog(context, ref),
                      icon: const Icon(Icons.pin_outlined),
                      label: const Text('Сопряжение по PIN'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _trustDiscoveredPeer(
    BuildContext context,
    WidgetRef ref,
    DiscoveredPeer peer,
  ) async {
    final store = await ref.read(deviceStoreProvider.future);
    await store.trustDevice(
      peerId: peer.peerId,
      name: peer.displayName,
      icon: 'device',
    );
    ref.read(discoveredPeersProvider.notifier).remove(peer.peerId);
    ref.invalidate(trustedDevicesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${peer.displayName}» добавлено')),
      );
    }
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(syncControllerProvider).runSync();
    if (!context.mounted) return;

    final message = switch (result.status) {
      SyncRunStatus.noPeers => result.message ?? 'Нет устройств для синхронизации',
      SyncRunStatus.completed => result.noteCount > 0
          ? 'Синхронизировано заметок: ${result.noteCount}'
          : 'Синхронизация завершена (ожидание libp2p)',
      SyncRunStatus.failed => result.message ?? 'Ошибка синхронизации',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPinPairingDialog(BuildContext context, WidgetRef ref) async {
    final pin = (100000 + Random.secure().nextInt(900000)).toString();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN-pairing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Покажите этот PIN на другом устройстве. '
              'После подключения libp2p сопряжение завершится автоматически.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SelectableText(
              pin,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'PIN другого устройства',
                hintText: '000000',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: () async {
              // Stub: manual trust for testing until libp2p lands.
              final store = await ref.read(deviceStoreProvider.future);
              await store.trustDevice(
                peerId: 'manual-${DateTime.now().millisecondsSinceEpoch}',
                name: 'Устройство (PIN)',
              );
              ref.invalidate(trustedDevicesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Добавить (заглушка)'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.title,
    required this.name,
    required this.peerId,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  final String title;
  final String name;
  final String peerId;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shortId =
        peerId.length > 12 ? '${peerId.substring(0, 8)}…' : peerId;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.22),
          child: Icon(icon, color: accent),
        ),
        title: Text(name),
        subtitle: Text('$title · $shortId'),
        trailing: trailing,
      ),
    );
  }
}
