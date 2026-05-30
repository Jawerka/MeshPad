import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/theme/meshpad_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final dataDirAsync = ref.watch(dataDirProvider);
    final customDirAsync = ref.watch(customDataDirProvider);
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
                    path,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  trailing: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _changeDataDir(path),
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
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            subtitle: const Text('MeshPad 0.1.0 · local-first Markdown'),
          ),
          const SizedBox(height: 8),
          Text(
            'Проверка обновлений и libp2p-синхронизация — в следующих спринтах.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MeshPadColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
