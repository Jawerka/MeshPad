import 'package:meshpad_core/meshpad_core.dart';

import 'pairing_protocol.dart';

/// Trusts a remote device after successful PIN pairing confirmation.
Future<void> trustDeviceFromPairingConfirm({
  required DeviceIdentityStore store,
  required PinPairingConfirm confirm,
  void Function()? onTrusted,
}) async {
  final initiatorId = confirm.initiatorPeerId;
  final host = confirm.initiatorLanHost;
  final port = confirm.initiatorHttpPort;
  if (initiatorId == null || host == null || port == null) return;

  await store.trustDevice(
    peerId: initiatorId,
    name: confirm.initiatorDisplayName ?? 'Устройство',
    lanHost: host,
    lanHttpPort: port,
    authToken: confirm.authToken,
    tlsCertSha256: confirm.initiatorTlsCertSha256,
    signingPublicKey: confirm.initiatorSigningPublicKey,
    signingKeyAlgorithm: confirm.initiatorSigningKeyAlgorithm,
  );
  onTrusted?.call();
}

/// Trusts a remote device after guest-side PIN confirmation (offer from host).
Future<void> trustDeviceFromPairingOffer({
  required DeviceIdentityStore store,
  required PinPairingOffer offer,
  required String lanHost,
  required int lanHttpPort,
  required String authToken,
  String? tlsCertSha256,
  void Function()? onTrusted,
}) async {
  await store.trustDevice(
    peerId: offer.peerId,
    name: offer.displayName,
    lanHost: lanHost,
    lanHttpPort: lanHttpPort,
    authToken: authToken,
    tlsCertSha256: tlsCertSha256,
    signingPublicKey: offer.signingPublicKey,
    signingKeyAlgorithm: offer.signingKeyAlgorithm,
  );
  onTrusted?.call();
}

/// Callback for [LanSyncTransport] when a remote peer completes PIN pairing.
Future<void> handleRemotePairingTrusted({
  required DeviceIdentityStore store,
  required PinPairingConfirm confirm,
}) =>
    trustDeviceFromPairingConfirm(store: store, confirm: confirm);
