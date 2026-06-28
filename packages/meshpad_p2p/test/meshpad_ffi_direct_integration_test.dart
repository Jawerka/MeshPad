import 'dart:io';

import 'package:meshpad_p2p/src/libp2p/ffi_direct_libp2p_native_api.dart';
import 'package:meshpad_p2p/src/libp2p/meshpad_ffi_bindings.dart';
import 'package:test/test.dart';

/// Requires `cargo build --lib` and `MESHPAD_LIBP2P_FFI=1` (CI `rust-sidecar` job).
void main() {
  test('direct FFI health + start/stop without HTTP', () async {
    final envFlag = Platform.environment['MESHPAD_LIBP2P_FFI'];
    final enabled = libp2pFfiEnabledFromEnvironment() ||
        envFlag == '1' ||
        envFlag?.toLowerCase() == 'true';
    if (!enabled) return;

    final ffi = MeshpadFfiBindings.tryLoad();
    if (ffi == null || !ffi.startDirect()) return;

    final api = FfiDirectLibp2pNativeApi(ffi);
    final health = await api.fetchHealth();
    expect(health?.ok, isTrue);
    expect(health?.backend, 'rust-libp2p');

    await api.start(peerId: 'ffi-direct', displayName: 'Direct');
    await api.stop();
  });
}
