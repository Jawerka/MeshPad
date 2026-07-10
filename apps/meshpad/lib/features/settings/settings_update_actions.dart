import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/services/apk_update_installer.dart';
import '../../core/services/update_checker.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsUpdateActions {
  SettingsUpdateActions({
    required UpdateChecker updateChecker,
    required ApkUpdateInstaller apkInstaller,
  })  : _updateChecker = updateChecker,
        _apkInstaller = apkInstaller;

  final UpdateChecker _updateChecker;
  final ApkUpdateInstaller _apkInstaller;

  static String? platformUpdateUrl(UpdateCheckResult result) {
    if (kIsWeb) return result.downloadUrl;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return result.windowsInstallerUrl ??
          result.windowsDownloadUrl ??
          result.downloadUrl;
    }
    return result.downloadUrl;
  }

  Future<void> checkAndShowDialog(
    BuildContext context, {
    required void Function(bool busy) setBusy,
  }) async {
    setBusy(true);
    try {
      final result = await _updateChecker.check();
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context);
      final message = switch (result.status) {
        UpdateCheckStatus.upToDate => l10n.updatesUpToDate(kAppVersion),
        UpdateCheckStatus.updateAvailable =>
          l10n.updatesAvailable(result.latestVersion ?? ''),
        UpdateCheckStatus.unavailable =>
          result.message ?? l10n.updatesUnavailable,
      };

      final updateUrl = platformUpdateUrl(result);
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
                      await downloadAndInstallApk(
                        context,
                        url: updateUrl,
                        setBusy: setBusy,
                      );
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
      if (context.mounted) setBusy(false);
    }
  }

  Future<void> downloadAndInstallApk(
    BuildContext context, {
    required String url,
    void Function(bool busy)? setBusy,
  }) async {
    if (!supportsInAppApkUpdate) return;

    final l10n = AppLocalizations.of(context);
    if (!context.mounted) return;

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

    setBusy?.call(true);
    try {
      final path = await _apkInstaller.downloadApk(
        url,
        onProgress: (received, totalBytes) {
          if (totalBytes != null && totalBytes > 0) {
            progressNotifier.value = received / totalBytes;
          }
        },
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      final install = await _apkInstaller.promptInstall(path);
      if (!context.mounted) return;
      if (install.type != ResultType.done) {
        showMeshPadHint(
          context,
          install.message.isNotEmpty
              ? install.message
              : l10n.updateInstallFailed,
          severity: StatusHintSeverity.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showMeshPadHint(
          context,
          l10n.updateDownloadFailed('$e'),
          severity: StatusHintSeverity.error,
        );
      }
    } finally {
      progressNotifier.dispose();
      if (context.mounted) setBusy?.call(false);
    }
  }
}
