import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import 'notes_providers.dart';
import 'secure_storage_providers.dart';

final gitSyncServiceProvider = FutureProvider<GitSyncService?>((ref) async {
  if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return null;
  final settings = await ref.watch(appSettingsProvider.future);
  if (!settings.gitSyncEnabled || settings.gitRepoUrl == null) return null;
  final dataDir = await ref.watch(dataDirProvider.future);
  final repo = await ref.watch(noteRepositoryProvider.future);
  final service = GitSyncService(dataDir: dataDir!, repository: repo);
  await service.ensureRepo(remoteUrl: settings.gitRepoUrl!);
  return service;
});

final gitSyncControllerProvider = Provider<GitSyncController>((ref) {
  return GitSyncController(ref);
});

class GitSyncController {
  GitSyncController(this._ref);

  final Ref _ref;

  Future<String?> _token() => _ref.read(secureGitTokenStoreProvider).read();

  Future<GitSyncResult> pull() async {
    final service = await _ref.read(gitSyncServiceProvider.future);
    if (service == null) {
      return const GitSyncResult.failed('Git sync not configured');
    }
    return service.pull(token: await _token());
  }

  Future<GitSyncResult> push({String message = 'MeshPad notes'}) async {
    final service = await _ref.read(gitSyncServiceProvider.future);
    if (service == null) {
      return const GitSyncResult.failed('Git sync not configured');
    }
    return service.push(message: message, token: await _token());
  }
}

final gitSyncLoopProvider = Provider<GitSyncLoop>((ref) {
  final loop = GitSyncLoop(ref);
  ref.onDispose(loop.dispose);
  return loop;
});

class GitSyncLoop {
  GitSyncLoop(this._ref);

  final Ref _ref;
  Timer? _timer;

  Future<void> start() async {
    _timer?.cancel();
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return;

    final settings = await _ref.read(appSettingsProvider.future);
    if (!settings.gitSyncEnabled) return;

    await _ref.read(gitSyncControllerProvider).pull();
    _timer = Timer.periodic(
      Duration(minutes: settings.gitPullIntervalMinutes),
      (_) => unawaited(_ref.read(gitSyncControllerProvider).pull()),
    );
  }

  void dispose() => _timer?.cancel();
}
