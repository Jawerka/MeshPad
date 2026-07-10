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
import '../../core/providers/sync_auth_health_provider.dart';
import '../../core/sync/sync_auth_messages.dart';
import '../../core/sync/sync_run_feedback.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/theme/device_icons.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'device_actions.dart';
import 'device_card.dart';
import 'devices_l10n.dart';
import 'pin_pairing_dialog.dart';

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
    final sheetContext = context;
    final identityAsync = ref.watch(localIdentityProvider);
    final trustedAsync = ref.watch(trustedDevicesProvider);
    final discovered = ref.watch(discoveredPeersProvider);
    final lan = readLanSyncTransport(ref);
    final trustedIds =
        trustedAsync.valueOrNull?.map((d) => d.peerId).toSet() ?? {};
    final visibleDiscovered =
        discovered.where((peer) => !trustedIds.contains(peer.peerId)).toList();
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
                      data: (identity) => DeviceCard(
                        name: identity.displayName,
                        subtitle: _localLanSubtitle(l10n, lan),
                        peerId: identity.peerId,
                        icon: peerIconFor(identity.icon),
                        accent: peerAccentColor(identity.peerId),
                        compact: compact,
                        onAvatarTap: () => _pickLocalIcon(
                          sheetContext,
                          ref,
                          identity.icon,
                          identity.peerId,
                        ),
                        trailing: LocalDeviceActions(
                          compact: compact,
                          onPickIcon: () => _pickLocalIcon(
                            sheetContext,
                            ref,
                            identity.icon,
                            identity.peerId,
                          ),
                          onRename: () => _renameLocalDevice(
                            sheetContext,
                            ref,
                            identity.displayName,
                          ),
                          onSync: () => _runSync(sheetContext, ref),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: MeshPadColors.textMuted,
                                ),
                          );
                        }
                        final authFailures =
                            ref.watch(peerSyncAuthFailedProvider);
                        return Column(
                          children: [
                            for (final device in devices)
                              DeviceCard(
                                name: device.name,
                                subtitle: _trustedLanSubtitle(l10n, device),
                                peerId: device.peerId,
                                icon: peerIconFor(device.icon),
                                accent: peerAccentColor(device.peerId),
                                compact: compact,
                                footer: authFailures.containsKey(device.peerId)
                                    ? Text(
                                        l10n.syncNeedsRePairTooltip,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: MeshPadColors.danger,
                                            ),
                                      )
                                    : null,
                                onAvatarTap: () => _pickTrustedIcon(
                                  sheetContext,
                                  ref,
                                  device,
                                ),
                                trailing: TrustedDeviceActions(
                                  compact: compact,
                                  onPickIcon: () => _pickTrustedIcon(
                                    sheetContext,
                                    ref,
                                    device,
                                  ),
                                  onRename: () => _renameTrustedDevice(
                                    sheetContext,
                                    ref,
                                    device,
                                  ),
                                  onSync: () => _runSyncWithPeer(
                                    sheetContext,
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
                                        .read(
                                            peerSyncAuthFailedProvider.notifier)
                                        .clearPeer(device.peerId);
                                    ref
                                        .read(discoveredPeersProvider.notifier)
                                        .remove(device.peerId);
                                    ref.invalidate(trustedDevicesProvider);
                                  },
                                ),
                              ),
                            if (devices.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _revokeAllTrusted(
                                    sheetContext,
                                    ref,
                                  ),
                                  child: Text(l10n.devicesRevokeAllTrusted),
                                ),
                              ),
                            ],
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
                            DeviceCard(
                              name: peer.displayName,
                              subtitle: _discoveredLanSubtitle(l10n, peer),
                              peerId: peer.peerId,
                              icon: Icons.wifi_tethering,
                              accent: peerAccentColor(peer.peerId),
                              compact: compact,
                              trailing: compact
                                  ? null
                                  : FilledButton.tonal(
                                      onPressed: () => _showPinPairingDialog(
                                        sheetContext,
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
                                          sheetContext,
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
                      onPressed: () => _showPinPairingDialog(sheetContext, ref),
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

  static String _localLanSubtitle(
      AppLocalizations l10n, LanSyncTransport? lan) {
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

  static String _discoveredLanSubtitle(
    AppLocalizations l10n,
    DiscoveredPeer peer,
  ) {
    final host = peer.lanHost;
    final port = peer.httpPort;
    if (host != null && port != null) {
      return l10n.devicesDiscoveredLan(host, port);
    }
    return l10n.devicesOnLan;
  }

  Future<void> _revokeAllTrusted(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.devicesRevokeAllTrustedTitle),
        content: Text(l10n.devicesRevokeAllTrustedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.devicesRevokeAllTrusted),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final removed =
        await ref.read(settingsControllerProvider).revokeAllTrustedDevices();
    if (!context.mounted) return;
    showMeshPadHint(
      context,
      l10n.devicesRevokeAllTrustedDone(removed),
      severity: StatusHintSeverity.success,
    );
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
      showMeshPadHint(
        context,
        l10n.devicesIconUpdated,
        severity: StatusHintSeverity.success,
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
      showMeshPadHint(
        context,
        l10n.devicesIconUpdatedNamed(device.name),
        severity: StatusHintSeverity.success,
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
      showMeshPadHint(
        context,
        l10n.deviceNameSaved(nextName),
        severity: StatusHintSeverity.success,
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
      showMeshPadHint(
        context,
        l10n.devicesTrustedRenamed(nextName),
        severity: StatusHintSeverity.success,
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

    if (lan == null) {
      if (!context.mounted) return;
      showMeshPadHint(context, l10n.devicesPeerUnreachable);
      return;
    }

    final store = await ref.read(deviceStoreProvider.future);
    final peerResult = await syncSingleTrustedPeer(
      transport: lan,
      deviceStore: store,
      peer: peer,
      timeout: const Duration(seconds: 120),
    );

    if (!context.mounted) return;

    if (peerResult.status == LanPeerSyncStatus.unreachable) {
      return;
    }

    final message = switch (peerResult.status) {
      LanPeerSyncStatus.completed when peerResult.noteCount > 0 =>
        l10n.devicesSyncNotesCount(peerResult.noteCount),
      LanPeerSyncStatus.completed => l10n.devicesSyncCompleted,
      LanPeerSyncStatus.failed ||
      LanPeerSyncStatus.unreachable =>
        peerResult.message ?? l10n.devicesSyncTimeout,
    };

    if (peerResult.status == LanPeerSyncStatus.completed) {
      ref.invalidate(trustedDevicesProvider);
      ref.invalidate(notesListProvider);
      ref.read(peerSyncAuthFailedProvider.notifier).clearPeer(peer.peerId);
    }

    if (!context.mounted) return;
    final displayMessage = syncRunUserMessage(message, l10n);
    showMeshPadHint(
      context,
      displayMessage,
      severity: peerResult.status == LanPeerSyncStatus.completed
          ? StatusHintSeverity.success
          : StatusHintSeverity.error,
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(syncControllerProvider).runSync();
    if (!context.mounted) return;
    showSyncRunFeedback(context, result);
  }

  Future<void> _showPinPairingDialog(
    BuildContext context,
    WidgetRef ref, {
    DiscoveredPeer? targetPeer,
  }) async {
    final asHost = targetPeer == null;
    final pin = asHost ? generatePairingPin() : '';
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    // Read providers before closing the sheet — its Consumer ref unmounts on pop.
    final identity = await ref.read(localIdentityProvider.future);
    final lan = readLanSyncTransport(ref);

    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    await Future<void>.delayed(Duration.zero);
    if (!rootContext.mounted) return;

    try {
      MeshPadLog.pairing(
        asHost
            ? 'opening pin dialog (host) pin=$pin'
            : 'opening pin dialog (guest) target=${targetPeer.peerId}',
      );

      final canScanQr =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

      Future<void> Function()? activateOffer;
      if (asHost && lan != null) {
        activateOffer = () => lan.setPairingOffer(
              createPairingOffer(
                peerId: identity.peerId,
                displayName: identity.displayName,
                pin: pin,
                signingPublicKey: identity.signingPublicKey,
                signingKeyAlgorithm: identity.signingKeyAlgorithm,
              ),
            );
      }

      await showDialog<void>(
        context: rootContext,
        useRootNavigator: true,
        builder: (dialogContext) => PinPairingDialog(
          pin: pin,
          asHost: asHost,
          lan: lan,
          activateOffer: activateOffer,
          canScanQr: canScanQr,
          lanAvailable: lan != null,
          initialPeer: targetPeer,
        ),
      );

      if (asHost && lan != null) {
        await lan.setPairingOffer(null);
      }
    } catch (e, st) {
      MeshPadLog.warn('pairing', 'pin dialog failed: $e');
      MeshPadLog.warn('pairing', '$st');
      if (rootContext.mounted) {
        final snackL10n = AppLocalizations.of(rootContext);
        showMeshPadHint(
          rootContext,
          snackL10n.devicesPairingConfirmFailed,
          severity: StatusHintSeverity.error,
        );
      }
    }
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
          showMeshPadHint(
            context,
            l10n.devicesManualProbeOk(endpoint.displayName),
            severity: StatusHintSeverity.success,
          );
        case ManualLanPeerProbeFailure(:final error):
          showMeshPadHint(
            context,
            error.message(l10n),
            severity: StatusHintSeverity.error,
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
