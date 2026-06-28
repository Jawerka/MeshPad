import 'dart:io';

import 'package:path/path.dart' as p;

import '../repositories/note_repository.dart';
import 'git_https_auth.dart';

/// Git sync mirrors `notes/<id>/note.md` + `meta.json` (no attachments).
class GitSyncService {
  GitSyncService({
    required this.dataDir,
    required this.repository,
    this.gitExecutable = 'git',
    this.runProcess = Process.run,
  });

  final String dataDir;
  final NoteRepository repository;
  final String gitExecutable;
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) runProcess;

  String get workTree => dataDir;
  String get gitDir => p.join(dataDir, '.git-sync');

  Future<void> ensureRepo({required String remoteUrl}) async {
    if (!await Directory(gitDir).exists()) {
      await Directory(gitDir).create(recursive: true);
      await _git(['init'], workingDirectory: gitDir);
    }
    await _writeGitignore();
    await _syncNotesToWorkTree();
    await _git(['remote', 'remove', 'origin'], workingDirectory: gitDir, allowFailure: true);
    await _git(['remote', 'add', 'origin', remoteUrl], workingDirectory: gitDir);
  }

  Future<GitSyncResult> pull({String? token}) async {
    await _syncNotesToWorkTree();
    final fetch = await _git(
      ['fetch', 'origin'],
      workingDirectory: gitDir,
      token: token,
      allowFailure: true,
    );
    if (fetch.exitCode != 0) {
      return GitSyncResult.failed(fetch.stderr.toString().trim());
    }
    final merge = await _git(
      ['merge', '--ff-only', 'origin/main'],
      workingDirectory: gitDir,
      allowFailure: true,
    );
    if (merge.exitCode != 0) {
      final rebase = await _git(
        ['merge', '--no-edit', 'origin/master'],
        workingDirectory: gitDir,
        allowFailure: true,
      );
      if (rebase.exitCode != 0) {
        return GitSyncResult.failed(merge.stderr.toString().trim());
      }
    }
    await _importFromWorkTree();
    return const GitSyncResult.ok();
  }

  Future<GitSyncResult> push({required String message, String? token}) async {
    await _syncNotesToWorkTree();
    await _git(['add', 'notes'], workingDirectory: gitDir);
    final status = await _git(['status', '--porcelain'], workingDirectory: gitDir);
    if (status.stdout.toString().trim().isEmpty) {
      return const GitSyncResult.ok(nothingToCommit: true);
    }
    await _git(['commit', '-m', message], workingDirectory: gitDir);
    final push = await _git(
      ['push', 'origin', 'HEAD:main'],
      workingDirectory: gitDir,
      token: token,
      allowFailure: true,
    );
    if (push.exitCode != 0) {
      final pushMaster = await _git(
        ['push', 'origin', 'HEAD:master'],
        workingDirectory: gitDir,
        token: token,
        allowFailure: true,
      );
      if (pushMaster.exitCode != 0) {
        return GitSyncResult.failed(push.stderr.toString().trim());
      }
    }
    return const GitSyncResult.ok();
  }

  Future<void> _syncNotesToWorkTree() async {
    final notesDir = p.join(dataDir, 'notes');
    final targetRoot = p.join(gitDir, 'notes');
    await Directory(targetRoot).create(recursive: true);
    if (!await Directory(notesDir).exists()) return;

    await for (final entity in Directory(notesDir).list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final noteMd = File(p.join(entity.path, 'note.md'));
      final metaJson = File(p.join(entity.path, 'meta.json'));
      if (!noteMd.existsSync() || !metaJson.existsSync()) continue;

      final outDir = Directory(p.join(targetRoot, id));
      await outDir.create(recursive: true);
      await noteMd.copy(p.join(outDir.path, 'note.md'));
      await metaJson.copy(p.join(outDir.path, 'meta.json'));
    }
  }

  Future<void> _importFromWorkTree() async {
    final source = Directory(p.join(gitDir, 'notes'));
    if (!await source.exists()) return;
    await repository.reconcileFromFilesystem();
  }

  Future<void> _writeGitignore() async {
    final file = File(p.join(gitDir, '.gitignore'));
    await file.writeAsString('''
**/attachments/**
**/.thumbs/**
''');
  }

  Future<ProcessResult> _git(
    List<String> args, {
    required String workingDirectory,
    String? token,
    bool allowFailure = false,
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    env['GIT_TERMINAL_PROMPT'] = '0';
    final result = await runProcess(
      gitExecutable,
      [
        ...gitHttpsAuthConfigArgs(token ?? ''),
        ...args,
        '--git-dir=$gitDir',
        '--work-tree=$gitDir',
      ],
      workingDirectory: workingDirectory,
      environment: env,
    );
    if (!allowFailure && result.exitCode != 0) {
      throw GitSyncException(
        result.stderr.toString().trim().isEmpty
            ? result.stdout.toString()
            : result.stderr.toString(),
      );
    }
    return result;
  }
}

class GitSyncResult {
  const GitSyncResult._(this.ok, {this.message, this.nothingToCommit = false});

  const GitSyncResult.ok({bool nothingToCommit = false})
      : this._(true, nothingToCommit: nothingToCommit);

  const GitSyncResult.failed(String message) : this._(false, message: message);

  final bool ok;
  final String? message;
  final bool nothingToCommit;
}

class GitSyncException implements Exception {
  GitSyncException(this.message);
  final String message;
  @override
  String toString() => 'GitSyncException: $message';
}
