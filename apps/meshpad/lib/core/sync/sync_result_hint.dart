import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/app_locale.dart';
import '../providers/notes_providers.dart';
import '../providers/sync_providers.dart';
import '../storage/app_settings.dart';
import '../ui/status_hint_provider.dart';
import 'sync_auth_messages.dart';

StatusHintSeverity _severityFor(SyncRunStatus status) => switch (status) {
      SyncRunStatus.failed => StatusHintSeverity.error,
      SyncRunStatus.partial => StatusHintSeverity.info,
      SyncRunStatus.noPeers => StatusHintSeverity.info,
      SyncRunStatus.completed => StatusHintSeverity.success,
    };

String? _messageFor(SyncRunResult result, AppLocalizations l10n) {
  if (result.status == SyncRunStatus.completed) return null;
  if (result.status == SyncRunStatus.partial && result.message == null) {
    return null;
  }

  return switch (result.status) {
    SyncRunStatus.noPeers => result.message ?? l10n.syncNoTrustedDevices,
    SyncRunStatus.partial => syncRunUserMessage(result.message, l10n).isNotEmpty
        ? syncRunUserMessage(result.message, l10n)
        : l10n.syncPartialDefault,
    SyncRunStatus.failed => syncRunUserMessage(result.message, l10n).isNotEmpty
        ? syncRunUserMessage(result.message, l10n)
        : l10n.syncFailedDefault,
    SyncRunStatus.completed => null,
  };
}

AppLocalizations _l10nForContainer(ProviderContainer container) {
  final settings = container.read(appSettingsProvider).valueOrNull;
  final localeMode = settings?.localeMode ?? AppLocaleMode.ru;
  final locale = resolveEffectiveLocale(
    mode: localeMode,
    platformLocale: null,
    supportedLocales: AppLocalizations.supportedLocales,
  );
  return lookupAppLocalizations(locale);
}

/// Shows a status hint for a sync run (no [BuildContext] required).
void showSyncResultHint(ProviderContainer container, SyncRunResult result) {
  final l10n = _l10nForContainer(container);
  final message = _messageFor(result, l10n);
  if (message == null || message.isEmpty) return;
  container.read(statusHintProvider.notifier).show(
        message,
        severity: _severityFor(result.status),
      );
}

/// Convenience for widgets with a [Ref].
void showSyncResultHintFromRef(Ref ref, SyncRunResult result) {
  showSyncResultHint(ref.container, result);
}
