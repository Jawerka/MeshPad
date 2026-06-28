import 'package:meshpad_p2p/src/libp2p/meshpad_ffi_bindings.dart';
import 'package:test/test.dart';

void main() {
  test('libp2pFfiEnabledFromEnvironment respects dart-define', () {
    expect(libp2pFfiEnabledFromEnvironment(), isFalse);
  });

  test('MeshpadFfiBindings.tryLoad returns null without native artifact', () {
    expect(MeshpadFfiBindings.tryLoad(), isNull);
  });

  test('shouldUseLibp2pFfiEmbed is false without bundled cdylib', () {
    expect(shouldUseLibp2pFfiEmbed(), isFalse);
  });

  test('hasBundledNativeLibrary is false on VM without jniLibs', () {
    expect(MeshpadFfiBindings.hasBundledNativeLibrary(), isFalse);
  });
}
