import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../core/providers/discovery_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import '../../l10n/app_localizations.dart';
import 'pairing_qr_ui.dart';

class PinPairingDialog extends ConsumerStatefulWidget {
  const PinPairingDialog({
    super.key,
    required this.pin,
    required this.asHost,
    this.lan,
    this.activateOffer,
    this.canScanQr = false,
    required this.lanAvailable,
    this.initialPeer,
  });

  final String pin;
  final bool asHost;
  final LanSyncTransport? lan;
  final Future<void> Function()? activateOffer;
  final bool canScanQr;
  final bool lanAvailable;
  final DiscoveredPeer? initialPeer;

  @override
  ConsumerState<PinPairingDialog> createState() => PinPairingDialogState();
}

class PinPairingDialogState extends ConsumerState<PinPairingDialog> {
  final _remotePinController = TextEditingController();
  DiscoveredPeer? _selectedPeer;
  var _confirming = false;
  String? _statusMessage;
  String? _qrPayload;
  StreamSubscription<SyncTransportEvent>? _pairingEventsSub;

  Timer? _qrRefreshTimer;

  String? _qrPayloadForLan(LanSyncTransport? lan) {
    if (lan == null) return null;
    final host = lan.localLanHost;
    final port = lan.localHttpPort;
    if (host == null || port == null) return null;
    return PairingQrPayload(
      host: host,
      httpPort: port,
      pin: widget.pin,
      tlsPort: lan.localTlsPort,
    ).encode();
  }

  void _scheduleQrRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _qrPayloadForLan(widget.lan);
      if (next == _qrPayload) return;
      setState(() => _qrPayload = next);
    });
  }

  Future<void> _activateOfferAfterFirstFrame() async {
    if (widget.lan != null) {
      try {
        await ref.read(discoveryServiceProvider).ensureRunning();
      } catch (e, st) {
        MeshPadLog.warn('pairing', 'ensureRunning before offer failed: $e');
        MeshPadLog.warn('pairing', '$st');
      }
    }

    final activate = widget.activateOffer;
    if (activate != null) {
      try {
        await activate();
      } catch (e, st) {
        MeshPadLog.warn('pairing', 'setPairingOffer failed: $e');
        MeshPadLog.warn('pairing', '$st');
      }
    }
    _scheduleQrRefresh();
  }

  void _startQrRefreshTimer() {
    _qrRefreshTimer?.cancel();
    if (!widget.asHost) return;
    _qrRefreshTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      final next = _qrPayloadForLan(widget.lan);
      if (next != _qrPayload) {
        setState(() => _qrPayload = next);
      }
      if (next != null) {
        _qrRefreshTimer?.cancel();
        _qrRefreshTimer = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedPeer = widget.initialPeer;
    if (widget.asHost) {
      _qrPayload = _qrPayloadForLan(widget.lan);
      _startQrRefreshTimer();
    }
    if (widget.activateOffer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_activateOfferAfterFirstFrame());
      });
    }
    if (widget.asHost && widget.lan != null) {
      _pairingEventsSub = widget.lan!.events.listen(
        _onPairingTransportEvent,
        onError: (Object error, StackTrace st) {
          MeshPadLog.warn('pairing', 'transport events error: $error');
          MeshPadLog.warn('pairing', '$st');
        },
      );
    }
  }

  void _onPairingTransportEvent(SyncTransportEvent event) {
    if (event is! PairingConfirmedRemotely || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final name = event.initiatorDisplayName?.trim();
    final label =
        (name != null && name.isNotEmpty) ? name : l10n.devicesPinPairing;
    setState(() {
      _confirming = false;
      _statusMessage = l10n.pairingCompletedWith(label);
    });
    showMeshPadHint(
      context,
      l10n.pairingCompletedWith(label),
      severity: StatusHintSeverity.success,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void didUpdateWidget(covariant PinPairingDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPeer == null && widget.initialPeer != null) {
      _selectedPeer = widget.initialPeer;
    }
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    unawaited(_pairingEventsSub?.cancel());
    _remotePinController.dispose();
    super.dispose();
  }

  Future<bool> _confirmPairing(
    String remotePin,
    DiscoveredPeer? targetPeer,
  ) async {
    final lan = widget.lan;
    if (lan == null || targetPeer == null) {
      if (mounted && lan == null) {
        final l10n = AppLocalizations.of(context);
        showMeshPadHint(context, l10n.devicesPairingNeedWifi);
      }
      return false;
    }

    try {
      final store = await ref.read(deviceStoreProvider.future);
      final identity = await ref.read(localIdentityProvider.future);
      final authToken = generateSyncAuthToken();

      await lan.start();
      final endpoint = lan.endpointFor(targetPeer.peerId) ??
          (await lan.resolvePeerEndpoint(
            peerId: targetPeer.peerId,
            stored: null,
          ));
      if (endpoint == null) {
        MeshPadLog.warn(
          'pairing',
          'confirm aborted: no endpoint for ${targetPeer.peerId}',
        );
        return false;
      }

      final offer = await lan.fetchPairingOffer(endpoint);
      if (offer == null) {
        MeshPadLog.warn(
          'pairing',
          'confirm aborted: no active offer at ${endpoint.host}:${endpoint.httpPort}',
        );
        return false;
      }
      if (offer.pin != remotePin) {
        MeshPadLog.warn(
          'pairing',
          'confirm aborted: pin mismatch (expected ${offer.pin}, got $remotePin)',
        );
        return false;
      }

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
      if (!ok) {
        MeshPadLog.warn(
          'pairing',
          'confirm HTTP failed for ${endpoint.host}:${endpoint.httpPort}',
        );
        return false;
      }

      await trustDeviceFromPairingOffer(
        store: store,
        offer: offer,
        lanHost: endpoint.host,
        lanHttpPort: endpoint.httpPort,
        authToken: authToken,
        tlsCertSha256: remoteTls,
        onTrusted: () => ref.invalidate(trustedDevicesProvider),
      );
      ref.read(discoveredPeersProvider.notifier).remove(offer.peerId);
      MeshPadLog.pairing('local trust saved for ${offer.peerId}');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showMeshPadHint(
          context,
          l10n.pairingCompletedWith(offer.displayName),
          severity: StatusHintSeverity.success,
        );
      }
      return true;
    } catch (e, st) {
      MeshPadLog.warn('pairing', 'confirm failed: $e');
      MeshPadLog.warn('pairing', '$st');
      return false;
    }
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
      showMeshPadHint(
        context,
        l10n.pairingQrProbeFailed,
        severity: StatusHintSeverity.error,
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
      showMeshPadHint(
        context,
        l10n.pairingQrPinMismatch,
        severity: StatusHintSeverity.error,
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

    final ok = await _confirmPairing(applied.payload.pin, peer);
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _statusMessage = null;
    });
    if (ok) {
      Navigator.pop(context);
      return;
    }
    showMeshPadHint(
      context,
      l10n.devicesPairingConfirmFailed,
      severity: StatusHintSeverity.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Rebuild only when the peer set changes, not on every UDP rediscovery tick.
    ref.watch(
      discoveredPeersProvider.select(
        (peers) => peers.map((p) => p.peerId).toList(growable: false),
      ),
    );
    final discovered = ref.read(discoveredPeersProvider);
    final selectedPeer = _selectedPeer ??
        (discovered.isEmpty
            ? null
            : (widget.initialPeer != null &&
                    discovered
                        .any((p) => p.peerId == widget.initialPeer!.peerId)
                ? widget.initialPeer
                : discovered.first));

    // Dialog (not AlertDialog): AlertDialog uses IntrinsicWidth which breaks
    // with scroll views and QrImageView's LayoutBuilder on mobile/desktop.
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                l10n.devicesPairingTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.asHost
                          ? l10n.pairingHostWaiting
                          : (widget.lanAvailable
                              ? l10n.pairingGuestIntro
                              : l10n.devicesPairingShowPinOnly),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (widget.asHost) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        widget.pin,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (_qrPayload != null) ...[
                        const SizedBox(height: 16),
                        PairingQrCodeView(payload: _qrPayload!),
                      ] else if (widget.lan != null) ...[
                        const SizedBox(height: 8),
                        const PairingQrLoadingView(),
                      ],
                    ],
                    if (!widget.asHost && widget.canScanQr) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _confirming ? null : _scanPairingQr,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        label: Text(l10n.pairingScanQr),
                      ),
                    ],
                    if (!widget.asHost &&
                        widget.lanAvailable &&
                        discovered.isNotEmpty) ...[
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
                            final selected =
                                selectedPeer?.peerId == peer.peerId;
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  leading: Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                  ),
                                  title: Text(
                                    peer.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () =>
                                      setState(() => _selectedPeer = peer),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                    if (!widget.asHost) ...[
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
                    ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _confirming
                        ? null
                        : () {
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text(l10n.close),
                  ),
                  if (!widget.asHost)
                    FilledButton(
                      onPressed: _confirming
                          ? null
                          : () async {
                              final remotePin =
                                  _remotePinController.text.trim();
                              if (!isValidPairingPin(remotePin)) {
                                showMeshPadHint(
                                  context,
                                  l10n.devicesPinInvalid,
                                );
                                return;
                              }

                              if (!widget.lanAvailable) {
                                showMeshPadHint(
                                  context,
                                  l10n.devicesPairingNeedWifi,
                                );
                                return;
                              }

                              final target = selectedPeer ??
                                  (discovered.isEmpty
                                      ? null
                                      : discovered.first);
                              if (target == null) {
                                showMeshPadHint(
                                  context,
                                  l10n.devicesPairingNoDiscovered,
                                );
                                return;
                              }

                              setState(() {
                                _confirming = true;
                                _statusMessage =
                                    l10n.pairingWaitingOn(target.displayName);
                              });
                              final ok =
                                  await _confirmPairing(remotePin, target);
                              if (!context.mounted) return;
                              setState(() {
                                _confirming = false;
                                _statusMessage = null;
                              });
                              if (ok) {
                                Navigator.pop(context);
                                return;
                              }
                              showMeshPadHint(
                                context,
                                l10n.devicesPairingConfirmFailed,
                                severity: StatusHintSeverity.error,
                              );
                            },
                      child: Text(l10n.devicesConfirm),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
