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

/// Callback for [LanSyncTransport] when a remote peer completes PIN pairing.
Future<void> handleRemotePairingTrusted({
  required DeviceIdentityStore store,
  required PinPairingConfirm confirm,
}) =>
    trustDeviceFromPairingConfirm(store: store, confirm: confirm);
