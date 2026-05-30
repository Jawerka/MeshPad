import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../core/providers/discovery_providers.dart';
import '../../core/providers/notes_providers.dart';
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.sync),
                                      tooltip: 'Синхронизировать',
                                      onPressed: () => _runSyncWithPeer(
                                        context,
                                        ref,
                                        device,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.link_off_outlined),
                                      tooltip: 'Отозвать доверие',
                                      onPressed: () async {
                                        final store = await ref
                                            .read(deviceStoreProvider.future);
                                        await store.revokeTrust(device.peerId);
                                        ref.invalidate(trustedDevicesProvider);
                                      },
                                    ),
                                  ],
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
                      'UDP discovery в локальной сети (до libp2p/mDNS)',
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
    final lan = readLanSyncTransport(ref);
    final endpoint = lan?.endpointFor(peer.peerId);
    final store = await ref.read(deviceStoreProvider.future);
    await store.trustDevice(
      peerId: peer.peerId,
      name: peer.displayName,
      icon: 'device',
      lanHost: endpoint?.host,
      lanHttpPort: endpoint?.httpPort,
    );
    ref.read(discoveredPeersProvider.notifier).remove(peer.peerId);
    ref.invalidate(trustedDevicesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${peer.displayName}» добавлено')),
      );
    }
  }

  Future<void> _runSyncWithPeer(
    BuildContext context,
    WidgetRef ref,
    Device peer,
  ) async {
    final transport = ref.read(syncTransportProvider);
    await transport.start();

    if (transport is LanSyncTransport) {
      rememberPeerEndpoint(transport, peer);
    }

    final completer = Completer<SyncTransportEvent>();
    late final StreamSubscription<SyncTransportEvent> sub;
    sub = transport.events.listen((event) {
      if (event is SyncCompleted || event is SyncFailed) {
        if (!completer.isCompleted) completer.complete(event);
      }
    });

    await transport.requestSync(peerId: peer.peerId);
    final event = await completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => SyncFailed(message: 'Таймаут синхронизации'),
    );
    await sub.cancel();

    if (!context.mounted) return;

    final message = switch (event) {
      SyncCompleted(:final noteCount) => noteCount > 0
          ? 'Синхронизировано заметок: $noteCount'
          : 'Синхронизация завершена',
      SyncFailed(:final message) => message,
      _ => 'Синхронизация завершена',
    };

    if (event is SyncCompleted) {
      final store = await ref.read(deviceStoreProvider.future);
      await store.markPeerSeen(peer.peerId);
      if (transport is LanSyncTransport) {
        final endpoint = transport.endpointFor(peer.peerId);
        if (endpoint != null) {
          await store.updateLanEndpoint(
            peerId: peer.peerId,
            lanHost: endpoint.host,
            lanHttpPort: endpoint.httpPort,
          );
        }
      }
      ref.invalidate(trustedDevicesProvider);
      ref.invalidate(notesListProvider);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(syncControllerProvider).runSync();
    if (!context.mounted) return;

    final message = switch (result.status) {
      SyncRunStatus.noPeers => result.message ?? 'Нет устройств для синхронизации',
      SyncRunStatus.completed => result.noteCount > 0
          ? 'Синхронизировано заметок: ${result.noteCount}'
          : 'Синхронизация завершена',
      SyncRunStatus.failed =>
        result.message ?? meshPadExceptionUserMessage('sync_failed'),
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPinPairingDialog(BuildContext context, WidgetRef ref) async {
    final pin = generatePairingPin();
    final identity = await ref.read(localIdentityProvider.future);
    final lan = readLanSyncTransport(ref);

    if (lan != null) {
      await lan.setPairingOffer(
        PinPairingOffer(
          peerId: identity.peerId,
          displayName: identity.displayName,
          pin: pin,
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PinPairingDialog(
        pin: pin,
        lanAvailable: lan != null,
        discovered: ref.read(discoveredPeersProvider),
        onConfirm: (remotePin, targetPeer) async {
          final store = await ref.read(deviceStoreProvider.future);

          if (lan != null && targetPeer != null) {
            final endpoint = lan.endpointFor(targetPeer.peerId);
            if (endpoint != null) {
              final offer = await lan.fetchPairingOffer(endpoint);
              if (offer != null && offer.pin == remotePin) {
                final ok = await lan.confirmPairingOnPeer(
                  endpoint: endpoint,
                  confirm: PinPairingConfirm(
                    peerId: offer.peerId,
                    pin: remotePin,
                  ),
                );
                if (ok) {
                  await store.trustDevice(
                    peerId: offer.peerId,
                    name: offer.displayName,
                    lanHost: endpoint.host,
                    lanHttpPort: endpoint.httpPort,
                  );
                  ref.invalidate(trustedDevicesProvider);
                  ref
                      .read(discoveredPeersProvider.notifier)
                      .remove(offer.peerId);
                  return true;
                }
              }
            }
            return false;
          }

          await store.trustDevice(
            peerId: 'pin-$remotePin',
            name: 'Устройство (PIN)',
          );
          ref.invalidate(trustedDevicesProvider);
          return true;
        },
        onClose: () async {
          if (lan != null) await lan.setPairingOffer(null);
        },
      ),
    );
    if (lan != null) await lan.setPairingOffer(null);
  }
}

class _PinPairingDialog extends StatefulWidget {
  const _PinPairingDialog({
    required this.pin,
    required this.lanAvailable,
    required this.discovered,
    required this.onConfirm,
    required this.onClose,
  });

  final String pin;
  final bool lanAvailable;
  final List<DiscoveredPeer> discovered;
  final Future<bool> Function(String remotePin, DiscoveredPeer? targetPeer)
      onConfirm;
  final Future<void> Function() onClose;

  @override
  State<_PinPairingDialog> createState() => _PinPairingDialogState();
}

class _PinPairingDialogState extends State<_PinPairingDialog> {
  final _remotePinController = TextEditingController();
  DiscoveredPeer? _selectedPeer;

  @override
  void initState() {
    super.initState();
    if (widget.discovered.isNotEmpty) {
      _selectedPeer = widget.discovered.first;
    }
  }

  @override
  void dispose() {
    _remotePinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN-pairing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.lanAvailable
                ? 'Покажите этот PIN на другом устройстве. '
                    'Выберите устройство в списке «Обнаруженные» для подтверждения.'
                : 'Покажите этот PIN на другом устройстве.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SelectableText(
            widget.pin,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          if (widget.lanAvailable && widget.discovered.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<DiscoveredPeer>(
              initialValue: _selectedPeer,
              decoration: const InputDecoration(
                labelText: 'Устройство в сети',
              ),
              items: [
                for (final peer in widget.discovered)
                  DropdownMenuItem(
                    value: peer,
                    child: Text(peer.displayName),
                  ),
              ],
              onChanged: (peer) => setState(() => _selectedPeer = peer),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _remotePinController,
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
          onPressed: () async {
            await widget.onClose();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Закрыть'),
        ),
        FilledButton(
          onPressed: () async {
            final remotePin = _remotePinController.text.trim();
            if (!isValidPairingPin(remotePin)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Введите 6-значный PIN')),
              );
              return;
            }

            if (widget.lanAvailable && widget.discovered.isNotEmpty) {
              final target = _selectedPeer ?? widget.discovered.first;
              final ok = await widget.onConfirm(remotePin, target);
              if (!context.mounted) return;
              if (ok) {
                Navigator.pop(context);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Не удалось подтвердить PIN. Проверьте устройство в сети.',
                  ),
                ),
              );
              return;
            }

            await widget.onConfirm(remotePin, null);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Подтвердить'),
        ),
      ],
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
