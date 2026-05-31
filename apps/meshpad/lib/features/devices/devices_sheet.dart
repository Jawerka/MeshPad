import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../l10n/app_localizations.dart';
import '../../core/providers/discovery_providers.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/theme/device_icons.dart';
import '../../core/theme/feed_layout.dart';
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
      builder: (sheetContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!sheetContext.mounted) return;
          final container = ProviderScope.containerOf(sheetContext);
          unawaited(container.read(discoveryServiceProvider).refresh());
        });
        return const DevicesSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(localIdentityProvider);
    final trustedAsync = ref.watch(trustedDevicesProvider);
    final discovered = ref.watch(discoveredPeersProvider);
    final lan = readLanSyncTransport(ref);
    final localLanSubtitle = _localLanSubtitle(lan);
    final trustedIds = trustedAsync.valueOrNull?.map((d) => d.peerId).toSet() ?? {};
    final visibleDiscovered = discovered
        .where((peer) => !trustedIds.contains(peer.peerId))
        .toList();
    final compact = isCompactFeedLayout(context);

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
                        name: identity.displayName,
                        subtitle: localLanSubtitle,
                        peerId: identity.peerId,
                        icon: peerIconFor(identity.icon),
                        accent: peerAccentColor(identity.peerId),
                        compact: compact,
                        onAvatarTap: () => _pickLocalIcon(
                          context,
                          ref,
                          identity.icon,
                          identity.peerId,
                        ),
                        trailing: _LocalDeviceActions(
                          compact: compact,
                          onPickIcon: () => _pickLocalIcon(
                            context,
                            ref,
                            identity.icon,
                            identity.peerId,
                          ),
                          onRename: () => _renameLocalDevice(
                            context,
                            ref,
                            identity.displayName,
                          ),
                          onSync: () => _runSync(context, ref),
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
                                name: device.name,
                                subtitle: _trustedLanSubtitle(device),
                                peerId: device.peerId,
                                icon: peerIconFor(device.icon),
                                accent: peerAccentColor(device.peerId),
                                compact: compact,
                                onAvatarTap: () => _pickTrustedIcon(
                                  context,
                                  ref,
                                  device,
                                ),
                                trailing: _TrustedDeviceActions(
                                  compact: compact,
                                  onPickIcon: () => _pickTrustedIcon(
                                    context,
                                    ref,
                                    device,
                                  ),
                                  onRename: () => _renameTrustedDevice(
                                    context,
                                    ref,
                                    device,
                                  ),
                                  onSync: () => _runSyncWithPeer(
                                    context,
                                    ref,
                                    device,
                                  ),
                                  onRevoke: () async {
                                    final store = await ref
                                        .read(deviceStoreProvider.future);
                                    await store.revokeTrust(device.peerId);
                                    readLanSyncTransport(ref)
                                        ?.forgetPeer(device.peerId);
                                    ref
                                        .read(discoveredPeersProvider.notifier)
                                        .remove(device.peerId);
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
                      AppLocalizations.of(context).devicesDiscoveryHint,
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
                              name: peer.displayName,
                              subtitle: 'В локальной сети',
                              peerId: peer.peerId,
                              icon: Icons.wifi_tethering,
                              accent: peerAccentColor(peer.peerId),
                              compact: compact,
                              trailing: compact
                                  ? null
                                  : FilledButton.tonal(
                                      onPressed: () => _showPinPairingDialog(
                                        context,
                                        ref,
                                        targetPeer: peer,
                                      ),
                                      child: const Text('PIN'),
                                    ),
                              footer: compact
                                  ? Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonal(
                                        onPressed: () => _showPinPairingDialog(
                                          context,
                                          ref,
                                          targetPeer: peer,
                                        ),
                                        child: const Text('PIN'),
                                      ),
                                    )
                                  : null,
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

  static String _localLanSubtitle(LanSyncTransport? lan) {
    final port = lan?.localHttpPort;
    if (port == null) return 'Это устройство';
    final host = lan?.localLanHost;
    if (host != null && host.isNotEmpty) {
      return 'Это устройство · LAN $host:$port';
    }
    return 'Это устройство · порт $port';
  }

  static String _trustedLanSubtitle(Device device) {
    if (device.hasLanEndpoint) {
      return 'Доверенное · ${device.lanHost}:${device.lanHttpPort}';
    }
    return 'Доверенное · LAN неизвестен';
  }

  Future<void> _pickLocalIcon(
    BuildContext context,
    WidgetRef ref,
    String currentIcon,
    String peerId,
  ) async {
    final picked = await showDeviceIconPicker(
      context,
      currentIcon: currentIcon,
      accent: peerAccentColor(peerId),
    );
    if (picked == null || picked == currentIcon) return;

    await ref.read(settingsControllerProvider).setLocalDeviceIcon(picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Иконка обновлена')),
      );
    }
  }

  Future<void> _pickTrustedIcon(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final picked = await showDeviceIconPicker(
      context,
      currentIcon: device.icon,
      accent: peerAccentColor(device.peerId),
    );
    if (picked == null || picked == device.icon) return;

    await ref.read(settingsControllerProvider).setTrustedDeviceIcon(
          peerId: device.peerId,
          icon: picked,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Иконка «${device.name}» обновлена')),
      );
    }
  }

  Future<void> _renameLocalDevice(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final nextName = await _promptDeviceName(
      context,
      title: 'Имя этого устройства',
      currentName: currentName,
      hint: 'Например: Рабочий ПК',
    );
    if (nextName == null || nextName == currentName) return;

    await ref.read(settingsControllerProvider).setLocalDisplayName(nextName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Имя изменено на «$nextName»')),
      );
    }
  }

  Future<void> _renameTrustedDevice(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final nextName = await _promptDeviceName(
      context,
      title: 'Имя устройства',
      currentName: device.name,
      hint: 'Как показывать в списке',
    );
    if (nextName == null || nextName == device.name) return;

    await ref.read(settingsControllerProvider).renameTrustedDevice(
          peerId: device.peerId,
          name: nextName,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«$nextName» переименовано')),
      );
    }
  }

  Future<String?> _promptDeviceName(
    BuildContext context, {
    required String title,
    required String currentName,
    required String hint,
  }) async {
    final result = await showTextInputDialog(
      context,
      title: title,
      initialValue: currentName,
      labelText: 'Имя',
      hintText: hint,
      textCapitalization: TextCapitalization.sentences,
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _runSyncWithPeer(
    BuildContext context,
    WidgetRef ref,
    Device peer,
  ) async {
    final transport = ref.read(syncTransportProvider);
    await transport.start();
    final lan = transport.lanAccess;

    if (lan != null) {
      final stored = peer.hasLanEndpoint
          ? LanPeerEndpoint(
              peerId: peer.peerId,
              displayName: peer.name,
              host: peer.lanHost!,
              httpPort: peer.lanHttpPort!,
            )
          : null;
      final endpoint = await lan.resolvePeerEndpoint(
        peerId: peer.peerId,
        stored: stored,
      );
      if (endpoint == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Устройство недоступно в сети. Проверьте Wi‑Fi и что MeshPad '
              'открыт на обоих устройствах.',
            ),
          ),
        );
        return;
      }
      lan.rememberEndpoint(endpoint);
    }

    final completer = Completer<SyncTransportEvent>();
    late final StreamSubscription<SyncTransportEvent> sub;
    sub = transport.events.listen((event) {
      if (event is SyncCompleted && event.peerId == peer.peerId) {
        if (!completer.isCompleted) completer.complete(event);
      } else if (event is SyncFailed &&
          (event.peerId == null || event.peerId == peer.peerId)) {
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
      if (lan != null) {
        final endpoint = lan.endpointFor(peer.peerId);
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

  Future<void> _showPinPairingDialog(
    BuildContext context,
    WidgetRef ref, {
    DiscoveredPeer? targetPeer,
  }) async {
    final pin = generatePairingPin();
    final identity = await ref.read(localIdentityProvider.future);
    final lan = readLanSyncTransport(ref);

    if (lan != null) {
      await lan.setPairingOffer(
        createPairingOffer(
          peerId: identity.peerId,
          displayName: identity.displayName,
          pin: pin,
        ),
      );
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PinPairingDialog(
        pin: pin,
        lanAvailable: lan != null,
        initialPeer: targetPeer,
        onConfirm: (remotePin, targetPeer) async {
          final store = await ref.read(deviceStoreProvider.future);
          final identity = await ref.read(localIdentityProvider.future);
          final authToken = generateSyncAuthToken();

          if (lan != null && targetPeer != null) {
            await lan.start();
            final endpoint = lan.endpointFor(targetPeer.peerId) ??
                (await lan.resolvePeerEndpoint(
                  peerId: targetPeer.peerId,
                  stored: null,
                ));
            if (endpoint != null) {
              final offer = await lan.fetchPairingOffer(endpoint);
              if (offer != null && offer.pin == remotePin) {
                final remoteTls = await lan.fetchPeerTlsCertSha256(endpoint);
                final ok = await lan.confirmPairingOnPeer(
                  endpoint: endpoint,
                  confirm: PinPairingConfirm(
                    peerId: offer.peerId,
                    pin: remotePin,
                    initiatorPeerId: identity.peerId,
                    initiatorDisplayName: identity.displayName,
                    initiatorLanHost: lan.localLanHost,
                    initiatorHttpPort: lan.localHttpPort,
                    authToken: authToken,
                    initiatorTlsCertSha256: lan.localTlsCertSha256,
                  ),
                );
                if (ok) {
                  await store.trustDevice(
                    peerId: offer.peerId,
                    name: offer.displayName,
                    lanHost: endpoint.host,
                    lanHttpPort: endpoint.httpPort,
                    authToken: authToken,
                    tlsCertSha256: remoteTls,
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

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Для PIN-pairing оба устройства должны быть в одной Wi‑Fi '
                  'сети и видны в «Обнаруженные».',
                ),
              ),
            );
          }
          return false;
        },
        onClose: () async {
          if (lan != null) await lan.setPairingOffer(null);
        },
      ),
    );
    if (lan != null) await lan.setPairingOffer(null);
  }
}

class _PinPairingDialog extends ConsumerStatefulWidget {
  const _PinPairingDialog({
    required this.pin,
    required this.lanAvailable,
    this.initialPeer,
    required this.onConfirm,
    required this.onClose,
  });

  final String pin;
  final bool lanAvailable;
  final DiscoveredPeer? initialPeer;
  final Future<bool> Function(String remotePin, DiscoveredPeer? targetPeer)
      onConfirm;
  final Future<void> Function() onClose;

  @override
  ConsumerState<_PinPairingDialog> createState() => _PinPairingDialogState();
}

class _PinPairingDialogState extends ConsumerState<_PinPairingDialog> {
  final _remotePinController = TextEditingController();
  DiscoveredPeer? _selectedPeer;

  @override
  void initState() {
    super.initState();
    _selectedPeer = widget.initialPeer;
  }

  @override
  void didUpdateWidget(covariant _PinPairingDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPeer == null && widget.initialPeer != null) {
      _selectedPeer = widget.initialPeer;
    }
  }

  @override
  void dispose() {
    _remotePinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final discovered = ref.watch(discoveredPeersProvider);
    final selectedPeer = _selectedPeer ??
        (discovered.isEmpty
            ? null
            : (widget.initialPeer != null &&
                    discovered.any((p) => p.peerId == widget.initialPeer!.peerId)
                ? widget.initialPeer
                : discovered.first));

    return AlertDialog(
      title: const Text('PIN-pairing'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 420,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.lanAvailable
                    ? 'Покажите этот PIN на другом устройстве. '
                        'Выберите устройство ниже для подтверждения.'
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
              if (widget.lanAvailable && discovered.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Устройство в сети',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (discovered.length == 1)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices_outlined),
                    title: Text(discovered.first.displayName),
                  )
                else
                  ...discovered.map(
                    (peer) {
                      final selected = selectedPeer?.peerId == peer.peerId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            title: Text(
                              peer.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => setState(() => _selectedPeer = peer),
                          ),
                        ),
                      );
                    },
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
        ),
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

            if (widget.lanAvailable && discovered.isNotEmpty) {
              final target = selectedPeer ?? discovered.first;
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

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Нет обнаруженных устройств. Дождитесь появления в списке '
                  '«Обнаруженные» или проверьте Wi‑Fi.',
                ),
              ),
            );
          },
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}

class _LocalDeviceActions extends StatelessWidget {
  const _LocalDeviceActions({
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
    if (compact) {
      return _DeviceActionsMenu(
        items: const [
          (value: 'icon', label: 'Иконка', icon: Icons.palette_outlined),
          (value: 'rename', label: 'Переименовать', icon: Icons.edit_outlined),
          (value: 'sync', label: 'Синхронизировать', icon: Icons.sync),
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
          tooltip: 'Иконка',
          onPressed: onPickIcon,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Переименовать',
          onPressed: onRename,
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Синхронизировать',
          onPressed: onSync,
        ),
      ],
    );
  }
}

class _TrustedDeviceActions extends StatelessWidget {
  const _TrustedDeviceActions({
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
    if (compact) {
      return _DeviceActionsMenu(
        items: const [
          (value: 'icon', label: 'Иконка', icon: Icons.palette_outlined),
          (value: 'rename', label: 'Переименовать', icon: Icons.edit_outlined),
          (value: 'sync', label: 'Синхронизировать', icon: Icons.sync),
          (
            value: 'revoke',
            label: 'Отозвать доверие',
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
          tooltip: 'Иконка',
          onPressed: onPickIcon,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Переименовать',
          onPressed: onRename,
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Синхронизировать',
          onPressed: onSync,
        ),
        IconButton(
          icon: const Icon(Icons.link_off_outlined),
          tooltip: 'Отозвать доверие',
          onPressed: onRevoke,
        ),
      ],
    );
  }
}

class _DeviceActionsMenu extends StatelessWidget {
  const _DeviceActionsMenu({
    required this.items,
    required this.onSelected,
  });

  final List<({String value, String label, IconData icon})> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Действия',
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.name,
    required this.subtitle,
    required this.peerId,
    required this.icon,
    required this.accent,
    this.trailing,
    this.footer,
    this.onAvatarTap,
    this.compact = false,
  });

  final String name;
  final String subtitle;
  final String peerId;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onAvatarTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      backgroundColor: accent.withValues(alpha: 0.22),
      child: Icon(icon, color: accent),
    );

    if (compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  onAvatarTap == null
                      ? avatar
                      : InkWell(
                          onTap: onAvatarTap,
                          customBorder: const CircleBorder(),
                          child: avatar,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: MeshPadColors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                footer!,
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: onAvatarTap == null
            ? avatar
            : InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: avatar,
              ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
