import 'dart:io';

import 'package:meshpad_p2p/src/libp2p/http_libp2p_native_api.dart';
import 'package:meshpad_p2p/src/libp2p/meshpad_ffi_bindings.dart';
import 'package:test/test.dart';

/// Requires `cargo build --lib` and `MESHPAD_LIBP2P_FFI=1` (CI `rust-sidecar` job).
void main() {
  test('embedded FFI sidecar health + start/stop', () async {
    final envFlag = Platform.environment['MESHPAD_LIBP2P_FFI'];
    final enabled = libp2pFfiEnabledFromEnvironment() ||
        envFlag == '1' ||
        envFlag?.toLowerCase() == 'true';
    if (!enabled) return;

    final ffi = MeshpadFfiBindings.tryLoad();
    if (ffi == null) return;

    final port = ffi.startEmbedded(port: 0);
    expect(port, greaterThan(0));

    final api = HttpLibp2pNativeApi(
      baseUrl: 'http://127.0.0.1:$port',
      embeddedFfiOwner: ffi,
    );
    final health = await api.fetchHealth();
    expect(health?.ok, isTrue);
    expect(health?.backend, 'rust-libp2p');

    await api.start(peerId: 'ffi-test', displayName: 'FFI');
    await api.stop();
    expect(ffi.embeddedPort, 0);
  });
}
