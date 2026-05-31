import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_messages.dart';
import '../../core/constants/app_info.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_loop_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/services/update_checker.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../devices/devices_sheet.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MeshPadColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => const SettingsSheet(),
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
      builder: (context) => AlertDialog(
        title: const Text('Сменить папку данных?'),
        content: Text(
          'Новая папка:\n$picked\n\n'
          'Заметки из текущей папки не переносятся автоматически. '
          'Скопируйте содержимое вручную, если нужно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сменить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await controller.setDataDirectory(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Папка данных: $picked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сменить папку: $e')),
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
      builder: (context) => AlertDialog(
        title: const Text('Вернуть папку по умолчанию?'),
        content: const Text(
          'Приложение снова будет использовать стандартную папку в профиле пользователя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).resetDataDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка данных сброшена')),
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

      final message = switch (result.status) {
        UpdateCheckStatus.upToDate => 'Установлена актуальная версия $kAppVersion',
        UpdateCheckStatus.updateAvailable =>
          'Доступна версия ${result.latestVersion}',
        UpdateCheckStatus.unavailable =>
          result.message ?? 'Не удалось проверить обновления',
      };

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Обновления'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
            if (result.status == UpdateCheckStatus.updateAvailable &&
                result.downloadUrl != null)
              FilledButton(
                onPressed: () async {
                  final uri = Uri.tryParse(result.downloadUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Скачать'),
              ),
          ],
        ),
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
      builder: (context) => AlertDialog(
        title: const Text('Очистить ошибки sync?'),
        content: const Text(
          'Записи outbox с исчерпанными повторами будут удалены. '
          'Сами заметки на диске не затрагиваются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final removed =
          await ref.read(settingsControllerProvider).purgeExhaustedOutbox();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed == 0
                  ? 'Нет записей с ошибками sync'
                  : 'Удалено записей outbox: $removed',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Индекс пересобран: $count заметок')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editLocalDisplayName(String currentName) async {
    if (_busy) return;

    final nextName = await showTextInputDialog(
      context,
      title: 'Имя устройства',
      initialValue: currentName,
      labelText: 'Имя',
      hintText: 'Видно другим устройствам в сети',
      textCapitalization: TextCapitalization.sentences,
    );

    if (nextName == null || nextName.isEmpty || nextName == currentName) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setLocalDisplayName(nextName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Имя: $nextName')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveApiUrl(String currentUrl) async {
    if (_busy) return;

    final nextUrl = await showTextInputDialog(
      context,
      title: 'URL сервера MeshPad',
      initialValue: currentUrl,
      labelText: 'Базовый URL API',
      hintText: 'http://127.0.0.1:8787',
    );

    if (nextUrl == null || nextUrl.isEmpty || nextUrl == currentUrl || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(settingsControllerProvider).setApiBaseUrl(nextUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сервер: $nextUrl')),
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
    final isWeb = ref.watch(isWebClientProvider);
    final dataDirAsync = ref.watch(dataDirProvider);
    final customDirAsync = ref.watch(customDataDirProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final failedAsync = ref.watch(outboxFailedCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text('Настройки', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (isWeb)
            ref.watch(webApiBaseUrlProvider).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(userFacingError(e)),
                  data: (url) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Сервер API'),
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
                )
          else
            dataDirAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Ошибка: $e'),
              data: (path) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Папка данных'),
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
                              child: const Text('По умолчанию'),
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
                    title: const Text('Имя устройства'),
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
              title: const Text('Устройства и синхронизация'),
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
                      title: const Text('Ошибки sync в очереди'),
                      subtitle: Text('$count записей с исчерпанными повторами'),
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
              error: (e, _) => Text('Настройки sync: $e'),
              data: (settings) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Автосинхронизация'),
                    subtitle: Text(
                      settings.autoSyncEnabled
                          ? 'Каждые ${settings.autoSyncIntervalMinutes} мин.'
                          : 'Выключена',
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
                              label: Text('$minutes мин'),
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
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Проверить данные'),
              subtitle: const Text(
                'Пересобрать индекс из файлов и создать отсутствующие превью',
              ),
              onTap: _busy ? null : _rebuildIndex,
            ),
          ],
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            subtitle: Text(
              isWeb
                  ? 'MeshPad Web · $kAppVersion'
                  : 'MeshPad $kAppVersion · local-first Markdown',
            ),
          ),
          if (!isWeb)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Проверить обновления'),
              onTap: _busy ? null : _checkUpdates,
            ),
          const SizedBox(height: 8),
          Text(
            isWeb
                ? 'Web-клиент подключается к headless-серверу (meshpad_server).'
                : 'LAN-синхронизация (mDNS/HTTP) с доверенными устройствами. Native libp2p — после MVP.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MeshPadColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
