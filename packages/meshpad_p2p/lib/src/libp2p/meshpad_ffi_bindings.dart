import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// C ABI from `native/meshpad_p2p_native` (PLAN §11.8.4).
final class MeshpadFfiBindings {
  MeshpadFfiBindings._(DynamicLibrary lib)
      : _startEmbedded = lib.lookupFunction<_StartNative, _StartDart>(
            'meshpad_ffi_start_embedded'),
        _stopEmbedded = lib.lookupFunction<_StopNative, _StopDart>(
            'meshpad_ffi_stop_embedded'),
        _embeddedPort = lib.lookupFunction<_PortNative, _PortDart>(
            'meshpad_ffi_embedded_port'),
        _startDirect = lib.lookupFunction<_StartDirectNative, _StartDirectDart>(
          'meshpad_ffi_start_direct',
        ),
        _stopDirect = lib.lookupFunction<_StopDirectNative, _StopDirectDart>(
          'meshpad_ffi_stop_direct',
        ),
        _request = lib.lookupFunction<_RequestNative, _RequestDart>(
          'meshpad_ffi_request',
        ),
        _pollEvent = lib.lookupFunction<_PollEventNative, _PollEventDart>(
          'meshpad_ffi_poll_event',
        ),
        _freeString = lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
          'meshpad_ffi_free_string',
        );

  final _StartDart _startEmbedded;
  final _StopDart _stopEmbedded;
  final _PortDart _embeddedPort;
  final _StartDirectDart _startDirect;
  final _StopDirectDart _stopDirect;
  final _RequestDart _request;
  final _PollEventDart _pollEvent;
  final _FreeStringDart _freeString;

  static MeshpadFfiBindings? _cached;

  /// Loads the native library when present on disk / in the APK (jniLibs).
  static MeshpadFfiBindings? tryLoad() {
    if (!Platform.isWindows &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isAndroid) {
      return null;
    }
    return _cached ??= _tryLoadUncached();
  }

  static MeshpadFfiBindings? _tryLoadUncached() {
    for (final path in _candidateLibraryPaths()) {
      try {
        return MeshpadFfiBindings._(DynamicLibrary.open(path));
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// True when the native library is bundled with the app (desktop path or Android jniLibs).
  static bool hasBundledNativeLibrary() {
    if (Platform.isAndroid) {
      try {
        DynamicLibrary.open(_libraryFileName());
        return true;
      } catch (_) {
        return false;
      }
    }
    for (final path in _executableAdjacentPaths(_libraryFileName())) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  static Iterable<String> _executableAdjacentPaths(String libName) sync* {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    yield p.join(exeDir, libName);
    if (Platform.isLinux) {
      yield p.join(exeDir, 'lib', libName);
    }
  }

  static Iterable<String> _candidateLibraryPaths() sync* {
    yield* _executableAdjacentPaths(_libraryFileName());
    const fromEnv = String.fromEnvironment('MESHPAD_LIBP2P_FFI_LIB');
    if (fromEnv.isNotEmpty) {
      yield fromEnv;
    }
    final fromPlatformEnv = Platform.environment['MESHPAD_LIBP2P_FFI_LIB'];
    if (fromPlatformEnv != null && fromPlatformEnv.isNotEmpty) {
      yield fromPlatformEnv;
    }

    final libName = _libraryFileName();
    yield libName;

    final manifestDir = Platform.environment['MESHPAD_REPO_ROOT'];
    if (manifestDir != null && manifestDir.isNotEmpty) {
      for (final profile in ['debug', 'release']) {
        yield '$manifestDir${Platform.pathSeparator}native${Platform.pathSeparator}meshpad_p2p_native'
            '${Platform.pathSeparator}target${Platform.pathSeparator}$profile'
            '${Platform.pathSeparator}$libName';
      }
    }

    final script = Platform.script.toFilePath();
    final pkgRoot =
        script.contains('packages${Platform.pathSeparator}meshpad_p2p')
            ? script.split('packages${Platform.pathSeparator}meshpad_p2p').first
            : null;
    if (pkgRoot != null) {
      for (final profile in ['debug', 'release']) {
        yield '$pkgRoot/native${Platform.pathSeparator}meshpad_p2p_native'
            '${Platform.pathSeparator}target${Platform.pathSeparator}$profile'
            '${Platform.pathSeparator}$libName';
      }
    }
  }

  static String _libraryFileName() {
    if (Platform.isWindows) return 'meshpad_p2p_native.dll';
    if (Platform.isMacOS) return 'libmeshpad_p2p_native.dylib';
    return 'libmeshpad_p2p_native.so';
  }

  /// Starts embedded HTTP sidecar; returns bound port or `0`.
  int startEmbedded({int port = 45839}) => _startEmbedded(port);

  int get embeddedPort => _embeddedPort();

  void stopEmbedded() {
    _stopEmbedded();
  }

  /// Starts direct in-process API (no loopback HTTP).
  bool startDirect() => _startDirect() == 1;

  void stopDirect() {
    _stopDirect();
  }

  /// Raw JSON response from a sidecar route.
  Future<dynamic> requestValue({
    required String path,
    required bool post,
    Map<String, dynamic>? body,
  }) async {
    final pathPtr = path.toNativeUtf8();
    Pointer<Utf8>? bodyPtr;
    try {
      if (body != null) {
        bodyPtr = jsonEncode(body).toNativeUtf8();
      }
      final resultPtr = _request(
        post ? 1 : 0,
        pathPtr.cast(),
        bodyPtr?.cast() ?? nullptr,
      );
      if (resultPtr == nullptr) {
        throw StateError('meshpad_ffi_request returned null');
      }
      try {
        final text = resultPtr.cast<Utf8>().toDartString();
        return jsonDecode(text);
      } finally {
        _freeString(resultPtr.cast());
      }
    } finally {
      malloc.free(pathPtr);
      if (bodyPtr != null) {
        malloc.free(bodyPtr);
      }
    }
  }

  Future<Map<String, dynamic>> requestJson({
    required String path,
    required bool post,
    Map<String, dynamic>? body,
  }) async {
    final value = await requestValue(path: path, post: post, body: body);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('expected JSON object from $path');
  }

  /// Returns the next native event, or null when empty.
  Map<String, dynamic>? pollEventJson() {
    final ptr = _pollEvent();
    if (ptr == nullptr) return null;
    try {
      final text = ptr.cast<Utf8>().toDartString();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } finally {
      _freeString(ptr.cast());
    }
  }
}

typedef _StartNative = Uint16 Function(Uint16 port);
typedef _StartDart = int Function(int port);
typedef _StopNative = Int32 Function();
typedef _StopDart = int Function();
typedef _PortNative = Uint16 Function();
typedef _PortDart = int Function();
typedef _StartDirectNative = Uint8 Function();
typedef _StartDirectDart = int Function();
typedef _StopDirectNative = Int32 Function();
typedef _StopDirectDart = int Function();
typedef _RequestNative = Pointer<Utf8> Function(
    Int32 method, Pointer<Utf8> path, Pointer<Utf8> body);
typedef _RequestDart = Pointer<Utf8> Function(
    int method, Pointer<Utf8> path, Pointer<Utf8> body);
typedef _PollEventNative = Pointer<Utf8> Function();
typedef _PollEventDart = Pointer<Utf8> Function();
typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

/// Whether FFI embedding is enabled (`MESHPAD_LIBP2P_FFI` / dart-define).
bool libp2pFfiEnabledFromEnvironment() {
  const fromDefine = String.fromEnvironment('MESHPAD_LIBP2P_FFI');
  if (fromDefine == '1' || fromDefine.toLowerCase() == 'true') {
    return true;
  }
  final env = Platform.environment['MESHPAD_LIBP2P_FFI'];
  return env == '1' || env?.toLowerCase() == 'true';
}

/// Use embedded sidecar when explicitly enabled or when the release bundle ships the cdylib.
bool shouldUseLibp2pFfiEmbed() {
  if (libp2pFfiEnabledFromEnvironment()) return true;
  const bundledDefine = String.fromEnvironment('MESHPAD_LIBP2P_FFI_BUNDLED');
  if (bundledDefine == '0' || bundledDefine.toLowerCase() == 'false') {
    return false;
  }
  return MeshpadFfiBindings.hasBundledNativeLibrary();
}

/// Prefer direct FFI (no loopback HTTP) when the cdylib is available.
bool shouldPreferLibp2pFfiDirect() {
  if (!shouldUseLibp2pFfiEmbed()) return false;
  const forceHttp = String.fromEnvironment('MESHPAD_LIBP2P_FFI_HTTP');
  if (forceHttp == '1' || forceHttp.toLowerCase() == 'true') return false;
  return true;
}
