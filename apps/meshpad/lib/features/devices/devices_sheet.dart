import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'devices_l10n.dart';
import 'pairing_qr_ui.dart';

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
    final trustedIds = trustedAsync.valueOrNull?.map((d) => d.peerId).toSet() ?? {};
    final visibleDiscovered = discovered
        .where((peer) => !trustedIds.contains(peer.peerId))
        .toList();
    final compact = isCompactFeedLayout(context);
    final l10n = AppLocalizations.of(context);

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
              Text(
                l10n.devicesSheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    identityAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(l10n.errorGeneric(e.toString())),
                      data: (identity) => _DeviceCard(
                        name: identity.displayName,
                        subtitle: _localLanSubtitle(l10n, lan),
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
                      l10n.devicesTrustedSection,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    trustedAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text(l10n.errorGeneric(e.toString())),
                      data: (devices) {
                        if (devices.isEmpty) {
                          return Text(
                            l10n.devicesTrustedEmpty,
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
                                subtitle: _trustedLanSubtitle(l10n, device),
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
                    _ManualPeerCard(compact: compact),
                    const SizedBox(height: 20),
                    Text(
                      l10n.devicesDiscoveredSection,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.devicesDiscoveryHint,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MeshPadColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleDiscovered.isEmpty)
                      Text(
                        l10n.devicesDiscovering,
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
                              subtitle: l10n.devicesOnLan,
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
                                      child: Text(l10n.devicesPinShort),
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
                                        child: Text(l10n.devicesPinShort),
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
                      label: Text(l10n.devicesPinPairing),
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

  static String _localLanSubtitle(AppLocalizations l10n, LanSyncTransport? lan) {
    final port = lan?.localHttpPort;
    if (port == null) return l10n.devicesThisDevice;
    final host = lan?.localLanHost;
    if (host != null && host.isNotEmpty) {
      return l10n.devicesThisDeviceLan(host, port);
    }
    return l10n.devicesThisDevicePort(port);
  }

  static String _trustedLanSubtitle(AppLocalizations l10n, Device device) {
    if (device.hasLanEndpoint) {
      return l10n.devicesTrustedLan(device.lanHost!, device.lanHttpPort!);
    }
    return l10n.devicesTrustedLanUnknown;
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.devicesIconUpdated)),
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.devicesIconUpdatedNamed(device.name))),
      );
    }
  }

  Future<void> _renameLocalDevice(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nextName = await _promptDeviceName(
      context,
      title: l10n.devicesLocalNameTitle,
      currentName: currentName,
      hint: l10n.devicesLocalNameHint,
      labelText: l10n.devicesNameLabel,
    );
    if (nextName == null || nextName == currentName) return;

    await ref.read(settingsControllerProvider).setLocalDisplayName(nextName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deviceNameSaved(nextName))),
      );
    }
  }

  Future<void> _renameTrustedDevice(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nextName = await _promptDeviceName(
      context,
      title: l10n.deviceNameTitle,
      currentName: device.name,
      hint: l10n.devicesTrustedRenameHint,
      labelText: l10n.devicesNameLabel,
    );
    if (nextName == null || nextName == device.name) return;

    await ref.read(settingsControllerProvider).renameTrustedDevice(
          peerId: device.peerId,
          name: nextName,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.devicesTrustedRenamed(nextName))),
      );
    }
  }

  Future<String?> _promptDeviceName(
    BuildContext context, {
    required String title,
    required String currentName,
    required String hint,
    required String labelText,
  }) async {
    final result = await showTextInputDialog(
      context,
      title: title,
      initialValue: currentName,
      labelText: labelText,
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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n.devicesPeerUnreachable)),
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
      onTimeout: () => SyncFailed(message: l10n.devicesSyncTimeout),
    );
    await sub.cancel();

    if (!context.mounted) return;

    final message = switch (event) {
      SyncCompleted(:final noteCount) => noteCount > 0
          ? l10n.devicesSyncNotesCount(noteCount)
          : l10n.devicesSyncCompleted,
      SyncFailed(:final message) => message,
      _ => l10n.devicesSyncCompleted,
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
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(syncControllerProvider).runSync();
    if (!context.mounted) return;

    final message = switch (result.status) {
      SyncRunStatus.noPeers =>
        result.message ?? l10n.devicesNoPeersToSync,
      SyncRunStatus.completed => result.noteCount > 0
          ? l10n.devicesSyncNotesCount(result.noteCount)
          : l10n.devicesSyncCompleted,
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
          signingPublicKey: identity.signingPublicKey,
          signingKeyAlgorithm: identity.signingKeyAlgorithm,
        ),
      );
    }

    if (!context.mounted) return;

    String? qrPayload;
    if (lan != null) {
      final host = lan.localLanHost;
      final port = lan.localHttpPort;
      if (host != null && port != null) {
        qrPayload = PairingQrPayload(
          host: host,
          httpPort: port,
          pin: pin,
          tlsPort: lan.localTlsPort,
        ).encode();
      }
    }
    final canScanQr =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PinPairingDialog(
        pin: pin,
        qrPayload: qrPayload,
        canScanQr: canScanQr,
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
                    initiatorSigningPublicKey: identity.signingPublicKey,
                    initiatorSigningKeyAlgorithm: identity.signingKeyAlgorithm,
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
                    signingPublicKey: offer.signingPublicKey,
                    signingKeyAlgorithm: offer.signingKeyAlgorithm,
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
            final snackL10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(snackL10n.devicesPairingNeedWifi)),
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
    this.qrPayload,
    this.canScanQr = false,
    required this.lanAvailable,
    this.initialPeer,
    required this.onConfirm,
    required this.onClose,
  });

  final String pin;
  final String? qrPayload;
  final bool canScanQr;
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
  var _confirming = false;
  String? _statusMessage;

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

  Future<void> _scanPairingQr() async {
    final payload = await showPairingQrScanner(context);
    if (payload == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _confirming = true;
      _statusMessage = l10n.pairingScanQr;
    });

    final applied = await ref.read(discoveryServiceProvider).probePairingQr(
          payload.encode(),
        );

    if (!mounted) return;

    if (applied == null) {
      setState(() {
        _confirming = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pairingQrProbeFailed)),
      );
      return;
    }

    final success = applied.probe;
    final offer = success.pairingOffer;
    if (offer != null && offer.pin != applied.payload.pin) {
      setState(() {
        _confirming = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pairingQrPinMismatch)),
      );
      return;
    }

    _remotePinController.text = applied.payload.pin;
    final discovered = ref.read(discoveredPeersProvider);
    DiscoveredPeer? target;
    for (final p in discovered) {
      if (p.peerId == success.endpoint.peerId) {
        target = p;
        break;
      }
    }

    final peer = target ??
        DiscoveredPeer(
          peerId: success.endpoint.peerId,
          displayName: success.endpoint.displayName,
          discoveredAt: DateTime.now().toUtc(),
        );

    setState(() {
      _selectedPeer = peer;
      _statusMessage = l10n.pairingWaitingOn(peer.displayName);
    });

    final ok = await widget.onConfirm(applied.payload.pin, peer);
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _statusMessage = null;
    });
    if (ok) {
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.devicesPairingConfirmFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final l10n = AppLocalizations.of(context);
    final discovered = ref.watch(discoveredPeersProvider);
    final selectedPeer = _selectedPeer ??
        (discovered.isEmpty
            ? null
            : (widget.initialPeer != null &&
                    discovered.any((p) => p.peerId == widget.initialPeer!.peerId)
                ? widget.initialPeer
                : discovered.first));

    return AlertDialog(
      title: Text(l10n.devicesPairingTitle),
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
                    ? l10n.devicesPairingShowPinSelectPeer
                    : l10n.devicesPairingShowPinOnly,
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
              if (widget.qrPayload != null) ...[
                const SizedBox(height: 16),
                PairingQrCodeView(payload: widget.qrPayload!),
              ],
              if (widget.canScanQr) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _confirming ? null : _scanPairingQr,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: Text(l10n.pairingScanQr),
                ),
              ],
              if (widget.lanAvailable && discovered.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.devicesPairingSelectPeer,
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
                decoration: InputDecoration(
                  labelText: l10n.devicesRemotePinLabel,
                  hintText: l10n.devicesRemotePinHint,
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !_confirming,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_confirming)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_confirming) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _confirming
              ? null
              : () async {
                  await widget.onClose();
                  if (context.mounted) Navigator.pop(context);
                },
          child: Text(l10n.close),
        ),
        FilledButton(
          onPressed: _confirming
              ? null
              : () async {
            final remotePin = _remotePinController.text.trim();
            if (!isValidPairingPin(remotePin)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.devicesPinInvalid)),
              );
              return;
            }

            if (widget.lanAvailable && discovered.isNotEmpty) {
              final target = selectedPeer ?? discovered.first;
              setState(() {
                _confirming = true;
                _statusMessage = l10n.pairingWaitingOn(target.displayName);
              });
              final ok = await widget.onConfirm(remotePin, target);
              if (!context.mounted) return;
              setState(() {
                _confirming = false;
                _statusMessage = null;
              });
              if (ok) {
                Navigator.pop(context);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.devicesPairingConfirmFailed)),
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.devicesPairingNoDiscovered)),
            );
          },
          child: Text(l10n.devicesConfirm),
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
    final l10n = AppLocalizations.of(context);
    if (compact) {
      return _DeviceActionsMenu(
        items: [
          (value: 'icon', label: l10n.devicesActionIcon, icon: Icons.palette_outlined),
          (value: 'rename', label: l10n.devicesActionRename, icon: Icons.edit_outlined),
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
    final l10n = AppLocalizations.of(context);
    if (compact) {
      return _DeviceActionsMenu(
        items: [
          (value: 'icon', label: l10n.devicesActionIcon, icon: Icons.palette_outlined),
          (value: 'rename', label: l10n.devicesActionRename, icon: Icons.edit_outlined),
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

class _DeviceActionsMenu extends StatelessWidget {
  const _DeviceActionsMenu({
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

class _ManualPeerCard extends ConsumerStatefulWidget {
  const _ManualPeerCard({required this.compact});

  final bool compact;

  @override
  ConsumerState<_ManualPeerCard> createState() => _ManualPeerCardState();
}

class _ManualPeerCardState extends ConsumerState<_ManualPeerCard> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '45838');
  var _probing = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _probing = true);
    try {
      final port = int.tryParse(_portController.text.trim()) ?? 45838;
      final result = await ref.read(discoveryServiceProvider).probeManualPeer(
            host: _hostController.text,
            httpPort: port,
          );
      if (!mounted) return;
      switch (result) {
        case ManualLanPeerProbeSuccess(:final endpoint):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.devicesManualProbeOk(endpoint.displayName)),
            ),
          );
        case ManualLanPeerProbeFailure(:final error):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message(l10n))),
          );
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.devicesManualPeerTitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            if (widget.compact) ...[
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: l10n.devicesManualHostLabel,
                  isDense: true,
                ),
                enabled: !_probing,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: l10n.devicesManualPortLabel,
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                enabled: !_probing,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostController,
                      decoration: InputDecoration(
                        labelText: l10n.devicesManualHostLabel,
                        isDense: true,
                      ),
                      enabled: !_probing,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: l10n.devicesManualPortLabel,
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_probing,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _probing ? null : _probe,
                child: _probing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.devicesManualProbe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
