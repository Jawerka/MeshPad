import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_messages.dart';
import '../../core/constants/app_info.dart';
import '../../core/providers/github_auth_providers.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_providers.dart';
import 'github_device_auth_dialog.dart';
import '../../core/services/apk_update_installer.dart';
import '../../core/services/update_checker.dart';
import '../../core/storage/app_settings.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/wifi_info.dart';
import '../devices/devices_sheet.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MeshPadColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            SettingsSheet(scrollController: scrollController),
      ),
    );
  }

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  bool _busy = false;
  final _updateChecker = UpdateChecker();
  final _apkInstaller = ApkUpdateInstaller();

  Future<void> _changeDataDir(String currentPath) async {
    if (_busy) return;

    final controller = ref.read(settingsControllerProvider);
    final picked = await controller.pickDataDirectory();
    if (!mounted || picked == null || picked == currentPath) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.changeDataDirTitle),
          content: Text(l10n.changeDataDirBody(picked)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.change),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await controller.setDataDirectory(picked);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.dataDirChanged(picked))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.dataDirChangeFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetDataDir() async {
    if (_busy) return;

    final isCustom =
        await ref.read(settingsControllerProvider).isCustomDataDir();
    if (!isCustom || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.resetDataDirTitle),
          content: Text(l10n.resetDataDirBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.reset),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).resetDataDirectory();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.dataDirReset)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _platformUpdateUrl(UpdateCheckResult result) {
    if (kIsWeb) return result.downloadUrl;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return result.windowsInstallerUrl ??
          result.windowsDownloadUrl ??
          result.downloadUrl;
    }
    return result.downloadUrl;
  }

  Future<void> _checkUpdates() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final result = await _updateChecker.check();
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      final message = switch (result.status) {
        UpdateCheckStatus.upToDate => l10n.updatesUpToDate(kAppVersion),
        UpdateCheckStatus.updateAvailable =>
          l10n.updatesAvailable(result.latestVersion ?? ''),
        UpdateCheckStatus.unavailable =>
          result.message ?? l10n.updatesUnavailable,
      };

      final updateUrl = _platformUpdateUrl(result);
      final canInstallApk = !kIsWeb &&
          supportsInAppApkUpdate &&
          result.status == UpdateCheckStatus.updateAvailable &&
          updateUrl != null;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = AppLocalizations.of(dialogContext);
          final whatsNew = result.whatsNewMarkdown?.trim();
          return AlertDialog(
            title: Text(dialogL10n.updatesTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message),
                  if (whatsNew != null && whatsNew.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      dialogL10n.updatesWhatsNew,
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: whatsNew,
                          shrinkWrap: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogL10n.close),
              ),
              if (result.status == UpdateCheckStatus.updateAvailable &&
                  updateUrl != null)
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    if (canInstallApk) {
                      await _downloadAndInstallApk(updateUrl);
                    } else {
                      final uri = Uri.tryParse(updateUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  child: Text(
                    canInstallApk
                        ? dialogL10n.updateDownloadInstall
                        : dialogL10n.download,
                  ),
                ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAndInstallApk(String url) async {
    if (_busy || !supportsInAppApkUpdate) return;

    final l10n = AppLocalizations.of(context);
    if (!mounted) return;

    final progressNotifier = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<double?>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final dialogL10n = AppLocalizations.of(dialogContext);
            return AlertDialog(
              title: Text(dialogL10n.updateDownloading),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null)
                    LinearProgressIndicator(value: progress)
                  else
                    const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    progress != null
                        ? dialogL10n.updateDownloadPercent(
                            (progress * 100).round(),
                          )
                        : dialogL10n.updateDownloading,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    setState(() => _busy = true);
    try {
      final path = await _apkInstaller.downloadApk(
        url,
        onProgress: (received, totalBytes) {
          if (totalBytes != null && totalBytes > 0) {
            progressNotifier.value = received / totalBytes;
          }
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final install = await _apkInstaller.promptInstall(path);
      if (!mounted) return;
      if (install.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              install.message.isNotEmpty
                  ? install.message
                  : l10n.updateInstallFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateDownloadFailed('$e'))),
        );
      }
    } finally {
      progressNotifier.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _updateChecker.close();
    _apkInstaller.close();
    super.dispose();
  }

  Future<void> _purgeFailedOutbox() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.purgeOutboxTitle),
          content: Text(l10n.purgeOutboxBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.clear),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final removed =
          await ref.read(settingsControllerProvider).purgeExhaustedOutbox();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed == 0
                  ? l10n.purgeOutboxNone
                  : l10n.purgeOutboxRemoved(removed),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebuildIndex() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final count = await ref.read(settingsControllerProvider).rebuildIndex();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.indexRebuilt(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneric('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editLocalDisplayName(String currentName) async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context);
    final nextName = await showTextInputDialog(
      context,
      title: l10n.deviceNameTitle,
      initialValue: currentName,
      labelText: l10n.deviceName,
      hintText: l10n.deviceNameHint,
      textCapitalization: TextCapitalization.sentences,
    );

    if (nextName == null || nextName.isEmpty || nextName == currentName) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setLocalDisplayName(nextName);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deviceNameSaved(nextName))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveApiKey(String? currentKey) async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context);
    final nextKey = await showTextInputDialog(
      context,
      title: l10n.apiKeyTitle,
      initialValue: currentKey ?? '',
      labelText: l10n.apiKey,
      hintText: l10n.apiKeyHint,
      obscureText: true,
    );

    if (nextKey == null || !mounted) return;
    if (nextKey == (currentKey ?? '')) return;

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setApiKey(
            nextKey.isEmpty ? null : nextKey,
          );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextKey.isEmpty ? l10n.apiKeyRemoved : l10n.apiKeySaved,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveApiUrl(String currentUrl) async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context);
    final nextUrl = await showTextInputDialog(
      context,
      title: l10n.apiUrlTitle,
      initialValue: currentUrl,
      labelText: l10n.apiUrlLabel,
      hintText: l10n.apiUrlHint,
    );

    if (nextUrl == null ||
        nextUrl.isEmpty ||
        nextUrl == currentUrl ||
        !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setApiBaseUrl(nextUrl);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.apiUrlSaved(nextUrl))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAutoBackupDirectory() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final picked =
        await ref.read(settingsControllerProvider).pickAutoBackupDirectory(
              dialogTitle: l10n.autoBackupPickDirectoryTitle,
            );
    if (!mounted || picked == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setAutoBackupDirectory(picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAutoBackupNow() async {
    if (_busy) return;
    final settings = await ref.read(appSettingsProvider.future);
    if (settings.autoBackupDirectory?.trim().isEmpty ?? true) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.autoBackupNeedDirectory)),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final count =
          await ref.read(settingsControllerProvider).runAutoBackupNow();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.autoBackupDone(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatBackupTimestamp(BuildContext context, DateTime utc) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('HH:mm dd.MM.yy', locale).format(utc.toLocal());
  }

  Future<void> _exportNotes() async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context);
    final stamp =
        DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportDialogTitle,
      fileName: 'meshpad-export-$stamp.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (savePath == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await ref
          .read(settingsControllerProvider)
          .exportNotesArchive(savePath);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportNotesCount(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importNotes() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.importNotesTitle),
          content: Text(l10n.importNotesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.selectFile),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: l10n.importArchiveDialogTitle,
    );
    if (picked == null || picked.files.single.path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(settingsControllerProvider)
          .importNotesArchive(picked.files.single.path!);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.importNotesResult(
                result.imported,
                result.updated,
                result.skipped,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWeb = ref.watch(isWebClientProvider);
    final dataDirAsync = ref.watch(dataDirProvider);
    final customDirAsync = ref.watch(customDataDirProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final failedAsync = ref.watch(outboxFailedCountProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MeshPadColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.settingsTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                if (isWeb) ...[
                  ref.watch(webApiBaseUrlProvider).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(userFacingError(e)),
                        data: (url) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_outlined),
                          title: Text(l10n.apiServer),
                          subtitle: Text(
                            url,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _busy ? null : () => _saveApiUrl(url),
                        ),
                      ),
                  ref.watch(webApiKeyProvider).when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => Text(userFacingError(e)),
                        data: (key) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.key_outlined),
                          title: Text(l10n.apiKey),
                          subtitle: Text(
                            key == null ? l10n.apiKeyNotSet : l10n.apiKeyMasked,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _busy ? null : () => _saveApiKey(key),
                        ),
                      ),
                ] else
                  dataDirAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(l10n.errorGeneric('$e')),
                    data: (path) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(l10n.dataFolder),
                          subtitle: Text(
                            path ?? '',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _busy || path == null
                              ? null
                              : () => _changeDataDir(path),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: customDirAsync.when(
                            data: (isCustom) => isCustom
                                ? TextButton(
                                    onPressed: _busy ? null : _resetDataDir,
                                    child: Text(l10n.defaultAction),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isWeb) ...[
                  ref.watch(localIdentityProvider).when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (identity) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(l10n.deviceName),
                          subtitle: Text(identity.displayName),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _busy
                              ? null
                              : () =>
                                  _editLocalDisplayName(identity.displayName),
                        ),
                      ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices),
                    title: Text(l10n.devicesAndSync),
                    trailing: failedAsync.when(
                      data: (count) => count > 0
                          ? Chip(
                              label: Text('$count'),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      DevicesSheet.show(context);
                    },
                  ),
                  failedAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (count) => count > 0
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.error_outline),
                            title: Text(l10n.syncOutboxErrors),
                            subtitle:
                                Text(l10n.syncOutboxErrorsSubtitle(count)),
                            trailing: _busy
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_outline),
                            onTap: _busy ? null : _purgeFailedOutbox,
                          )
                        : const SizedBox.shrink(),
                  ),
                  settingsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text(l10n.syncSettingsError('$e')),
                    data: (settings) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.autoSync),
                          subtitle: Text(
                            settings.autoSyncEnabled
                                ? l10n.autoSyncEvery(
                                    settings.autoSyncIntervalMinutes)
                                : l10n.autoSyncOff,
                          ),
                          value: settings.autoSyncEnabled,
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  await ref
                                      .read(settingsControllerProvider)
                                      .setAutoSyncEnabled(value);
                                },
                        ),
                        if (settings.autoSyncEnabled)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (final minutes in const [15, 30, 60])
                                  ChoiceChip(
                                    label: Text(l10n.minutesShort(minutes)),
                                    selected:
                                        settings.autoSyncIntervalMinutes ==
                                            minutes,
                                    onSelected: _busy
                                        ? null
                                        : (_) async {
                                            await ref
                                                .read(
                                                    settingsControllerProvider)
                                                .setAutoSyncIntervalMinutes(
                                                    minutes);
                                          },
                                  ),
                              ],
                            ),
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.gentleNetworkMode),
                          subtitle: Text(l10n.gentleNetworkModeHint),
                          value: settings.networkProfile ==
                              LanNetworkProfile.gentle,
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  await ref
                                      .read(settingsControllerProvider)
                                      .setNetworkProfile(
                                        value
                                            ? LanNetworkProfile.gentle
                                            : LanNetworkProfile.normal,
                                      );
                                },
                        ),
                        if (!kIsWeb && Platform.isAndroid)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                'Синхронизация только в выбранных Wi‑Fi'),
                            subtitle: Text(
                              settings.allowedWifiSsids.isEmpty
                                  ? 'Добавьте сеть ниже'
                                  : settings.allowedWifiSsids.join(', '),
                            ),
                            value: settings.syncOnlyOnAllowedWifi,
                            onChanged: _busy
                                ? null
                                : (value) => ref
                                    .read(settingsControllerProvider)
                                    .setSyncOnlyOnAllowedWifi(value),
                          ),
                        if (!kIsWeb && Platform.isAndroid)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Добавить текущую Wi‑Fi'),
                            trailing: const Icon(Icons.wifi),
                            onTap: _busy
                                ? null
                                : () async {
                                    final ssid =
                                        await WifiInfoPlatform.currentSsid();
                                    if (ssid == null || ssid.isEmpty) return;
                                    await ref
                                        .read(settingsControllerProvider)
                                        .addAllowedWifiSsid(ssid);
                                  },
                          ),
                        if (!kIsWeb &&
                            (Platform.isWindows || Platform.isLinux)) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Git sync (GitHub)'),
                            subtitle: Text(settings.gitRepoUrl ??
                                'Укажите URL репозитория'),
                            value: settings.gitSyncEnabled,
                            onChanged: _busy
                                ? null
                                : (value) => ref
                                    .read(settingsControllerProvider)
                                    .setGitSyncEnabled(value),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('URL приватного репозитория'),
                            subtitle: Text(settings.gitRepoUrl ??
                                'https://github.com/user/repo.git'),
                            onTap: _busy
                                ? null
                                : () async {
                                    final controller = TextEditingController(
                                      text: settings.gitRepoUrl ?? '',
                                    );
                                    final url = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Git repository URL'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'https://github.com/user/repo.git',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Отмена'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                                ctx, controller.text),
                                            child: const Text('Сохранить'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (url == null) return;
                                    await ref
                                        .read(settingsControllerProvider)
                                        .setGitRepoUrl(url);
                                  },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('GitHub OAuth Client ID'),
                            subtitle: Text(
                              settings.githubOAuthClientId?.isNotEmpty == true
                                  ? settings.githubOAuthClientId!
                                  : 'Нужен для входа через браузер (см. docs/GIT_SYNC.md)',
                            ),
                            onTap: _busy
                                ? null
                                : () async {
                                    final controller = TextEditingController(
                                      text: settings.githubOAuthClientId ?? '',
                                    );
                                    final clientId = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            'GitHub OAuth Client ID'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            hintText: 'Ov23li…',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Отмена'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                                ctx, controller.text),
                                            child: const Text('Сохранить'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (clientId == null) return;
                                    await ref
                                        .read(settingsControllerProvider)
                                        .setGithubOAuthClientId(clientId);
                                  },
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final auth = ref.watch(githubAuthStateProvider);
                              return auth.when(
                                loading: () => const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('GitHub'),
                                  subtitle: Text('Проверка…'),
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (state) {
                                  if (state.connected) {
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('GitHub: ${state.login}'),
                                      subtitle: const Text('Аккаунт подключён'),
                                      trailing: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () async {
                                                await ref
                                                    .read(
                                                        githubAuthControllerProvider)
                                                    .signOut();
                                              },
                                        child: const Text('Выйти'),
                                      ),
                                    );
                                  }
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Войти через GitHub'),
                                    subtitle: const Text(
                                      'Браузер + код устройства (OAuth Device Flow)',
                                    ),
                                    trailing: FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              setState(() => _busy = true);
                                              try {
                                                await showGitHubDeviceAuthDialog(
                                                  context,
                                                  ref,
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(() => _busy = false);
                                                }
                                              }
                                            },
                                      child: const Text('Войти'),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.themeSection,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final entry in [
                                    (AppThemeMode.dark, l10n.themeDark),
                                    (AppThemeMode.light, l10n.themeLight),
                                    (AppThemeMode.system, l10n.themeSystem),
                                  ])
                                    ChoiceChip(
                                      label: Text(entry.$2),
                                      selected: settings.themeMode == entry.$1,
                                      onSelected: _busy
                                          ? null
                                          : (_) async {
                                              await ref
                                                  .read(
                                                      settingsControllerProvider)
                                                  .setThemeMode(entry.$1);
                                            },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.localeSection,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final entry in [
                                    (AppLocaleMode.ru, l10n.localeRu),
                                    (AppLocaleMode.en, l10n.localeEn),
                                    (AppLocaleMode.system, l10n.localeSystem),
                                  ])
                                    ChoiceChip(
                                      label: Text(entry.$2),
                                      selected: settings.localeMode == entry.$1,
                                      onSelected: _busy
                                          ? null
                                          : (_) async {
                                              await ref
                                                  .read(
                                                      settingsControllerProvider)
                                                  .setLocaleMode(entry.$1);
                                            },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(l10n.exportNotes),
                    subtitle: Text(l10n.exportNotesSubtitle),
                    onTap: _busy ? null : _exportNotes,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: Text(l10n.importNotes),
                    subtitle: Text(l10n.importNotesSubtitle),
                    onTap: _busy ? null : _importNotes,
                  ),
                  if (!isWeb)
                    settingsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (settings) {
                        final backupDir = settings.autoBackupDirectory?.trim();
                        final hasDir =
                            backupDir != null && backupDir.isNotEmpty;
                        String autoBackupSubtitle;
                        if (!settings.autoBackupEnabled) {
                          autoBackupSubtitle = l10n.autoBackupOff;
                        } else if (!hasDir) {
                          autoBackupSubtitle = l10n.autoBackupNeedDirectory;
                        } else {
                          autoBackupSubtitle = l10n.autoBackupEveryHours(
                              settings.autoBackupIntervalHours);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.autoBackup),
                              subtitle: Text(autoBackupSubtitle),
                              value: settings.autoBackupEnabled,
                              onChanged: _busy
                                  ? null
                                  : (value) async {
                                      await ref
                                          .read(settingsControllerProvider)
                                          .setAutoBackupEnabled(value);
                                    },
                            ),
                            if (settings.autoBackupEnabled) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, bottom: 8),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    for (final hours in const [12, 24, 48, 168])
                                      ChoiceChip(
                                        label: Text(l10n.hoursShort(hours)),
                                        selected:
                                            settings.autoBackupIntervalHours ==
                                                hours,
                                        onSelected: _busy
                                            ? null
                                            : (_) async {
                                                await ref
                                                    .read(
                                                        settingsControllerProvider)
                                                    .setAutoBackupIntervalHours(
                                                        hours);
                                              },
                                      ),
                                  ],
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.folder_zip_outlined),
                                title: Text(l10n.autoBackupDirectory),
                                subtitle: Text(
                                  hasDir
                                      ? backupDir
                                      : l10n.autoBackupDirectoryNone,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                trailing: _busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: _busy ? null : _pickAutoBackupDirectory,
                              ),
                              if (hasDir)
                                Text(
                                  settings.autoBackupLastAt == null
                                      ? l10n.autoBackupNever
                                      : l10n.autoBackupLastRun(
                                          _formatBackupTimestamp(
                                            context,
                                            settings.autoBackupLastAt!,
                                          ),
                                        ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: MeshPadColors.textMuted,
                                      ),
                                ),
                              if (hasDir)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.backup_outlined),
                                  title: Text(l10n.autoBackupNow),
                                  subtitle: Text(l10n.autoBackupNowSubtitle),
                                  onTap: _busy ? null : _runAutoBackupNow,
                                ),
                            ],
                          ],
                        );
                      },
                    ),
                  if (!isWeb)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: settingsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (settings) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.thumbCacheSection,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.thumbCacheLimit(settings.thumbCacheMaxMb),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: MeshPadColors.textMuted,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final mb in const [128, 256, 512, 1024])
                                  ChoiceChip(
                                    label: Text(l10n.thumbCacheMb(mb)),
                                    selected: settings.thumbCacheMaxMb == mb,
                                    onSelected: _busy
                                        ? null
                                        : (_) async {
                                            await ref
                                                .read(
                                                    settingsControllerProvider)
                                                .setThumbCacheMaxMb(mb);
                                          },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isWeb)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.build_circle_outlined),
                      title: Text(l10n.verifyData),
                      subtitle: Text(l10n.verifyDataSubtitle),
                      onTap: _busy ? null : _rebuildIndex,
                    ),
                ],
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.about),
                  subtitle: Text(
                    isWeb
                        ? l10n.aboutWeb(kAppVersion)
                        : l10n.aboutNative(kAppVersion),
                  ),
                ),
                if (!isWeb)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.system_update_alt),
                    title: Text(l10n.checkUpdates),
                    onTap: _busy ? null : _checkUpdates,
                  ),
                const SizedBox(height: 8),
                Text(
                  isWeb ? l10n.footerWeb : l10n.footerNative,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MeshPadColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
