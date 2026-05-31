import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_messages.dart';
import '../../core/constants/app_info.dart';
import '../../core/constants/feature_flags.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/services/update_checker.dart';
import '../../core/storage/app_settings.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
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

    final isCustom = await ref.read(settingsControllerProvider).isCustomDataDir();
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

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(dialogL10n.updatesTitle),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogL10n.close),
              ),
              if (result.status == UpdateCheckStatus.updateAvailable &&
                  result.downloadUrl != null)
                FilledButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(result.downloadUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: Text(dialogL10n.download),
                ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _updateChecker.close();
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

    if (nextUrl == null || nextUrl.isEmpty || nextUrl == currentUrl || !mounted) {
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
          Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleMedium),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => _editLocalDisplayName(identity.displayName),
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
                      subtitle: Text(l10n.syncOutboxErrorsSubtitle(count)),
                      trailing: _busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                          ? l10n.autoSyncEvery(settings.autoSyncIntervalMinutes)
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
                                  settings.autoSyncIntervalMinutes == minutes,
                              onSelected: _busy
                                  ? null
                                  : (_) async {
                                      await ref
                                          .read(settingsControllerProvider)
                                          .setAutoSyncIntervalMinutes(minutes);
                                    },
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
                                            .read(settingsControllerProvider)
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
                                            .read(settingsControllerProvider)
                                            .setLocaleMode(entry.$1);
                                      },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (MeshPadFeatureFlags.libp2pTransportSettingVisible)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.syncTransportSection,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(l10n.syncTransportLan),
                                selected: settings.syncTransportKind ==
                                    SyncTransportKind.lan,
                                onSelected: _busy
                                    ? null
                                    : (_) async {
                                        await ref
                                            .read(settingsControllerProvider)
                                            .setSyncTransportKind(
                                              SyncTransportKind.lan,
                                            );
                                      },
                              ),
                              ChoiceChip(
                                label: Text(l10n.syncTransportLibp2p),
                                selected: settings.syncTransportKind ==
                                    SyncTransportKind.libp2p,
                                onSelected: _busy
                                    ? null
                                    : (_) async {
                                        await ref
                                            .read(settingsControllerProvider)
                                            .setSyncTransportKind(
                                              SyncTransportKind.libp2p,
                                            );
                                      },
                              ),
                            ],
                          ),
                          Text(
                            settings.syncTransportKind ==
                                    SyncTransportKind.libp2p
                                ? l10n.syncTransportLibp2pHint
                                : l10n.syncTransportLanHint,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: MeshPadColors.textMuted,
                                ),
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
