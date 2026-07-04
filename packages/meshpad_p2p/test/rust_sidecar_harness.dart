import 'dart:io';

/// Locates or builds the Rust sidecar binary for integration tests (PLAN 8.3).
class RustSidecarHarness {
  RustSidecarHarness._(this.binaryPath);

  final String binaryPath;

  static Future<RustSidecarHarness?> tryCreate() async {
    final repoRoot = _repoRoot();
    final manifest = Directory(
      '$repoRoot${Platform.pathSeparator}native${Platform.pathSeparator}meshpad_p2p_native',
    );
    if (!await manifest.exists()) return null;

    for (final profile in ['debug', 'release']) {
      final path = _binaryPath(manifest.path, profile);
      if (await File(path).exists()) {
        return RustSidecarHarness._(path);
      }
    }

    final cargo = Platform.isWindows ? 'cargo.exe' : 'cargo';
    final build = await Process.run(
      cargo,
      [
        'build',
        '--manifest-path',
        '${manifest.path}${Platform.pathSeparator}Cargo.toml',
      ],
      runInShell: Platform.isWindows,
    );
    if (build.exitCode != 0) return null;

    final debugPath = _binaryPath(manifest.path, 'debug');
    if (!await File(debugPath).exists()) return null;
    return RustSidecarHarness._(debugPath);
  }

  static String _repoRoot() {
    final testDir = File(Platform.script.toFilePath()).parent;
    return Directory(
      '${testDir.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..',
    ).resolveSymbolicLinksSync();
  }

  static String _binaryPath(String manifestPath, String profile) {
    final name =
        Platform.isWindows ? 'meshpad_p2p_sidecar.exe' : 'meshpad_p2p_sidecar';
    return '$manifestPath${Platform.pathSeparator}target'
        '${Platform.pathSeparator}$profile'
        '${Platform.pathSeparator}$name';
  }

  static Future<int> findFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<Process> start({required int port}) {
    return Process.start(
      binaryPath,
      ['--port', '$port'],
      environment: {
        ...Platform.environment,
        'MESHPAD_LIBP2P_SIDECAR_PORT': '$port',
      },
    );
  }

  static Future<void> waitForHealth(String baseUrl) async {
    final client = HttpClient();
    try {
      for (var attempt = 0; attempt < 80; attempt++) {
        try {
          final request = await client.getUrl(Uri.parse('$baseUrl/health'));
          final response = await request.close().timeout(
                const Duration(seconds: 2),
              );
          if (response.statusCode == 200) return;
        } on Object {
          // retry
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      throw StateError('sidecar not healthy at $baseUrl');
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> stopProcess(Process process) async {
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}
