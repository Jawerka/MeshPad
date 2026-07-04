import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/github_auth_providers.dart';
import '../../core/services/github_device_auth_service.dart';
import '../../core/theme/meshpad_colors.dart';

Future<bool> showGitHubDeviceAuthDialog(
    BuildContext context, WidgetRef ref) async {
  final controller = ref.read(githubAuthControllerProvider);
  GitHubDeviceCode? deviceCode;
  try {
    deviceCode = await controller.startDeviceFlow();
  } on GitHubDeviceAuthException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }

  if (!context.mounted) return false;

  final uri = Uri.parse(deviceCode.verificationUri);
  await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _GitHubDeviceAuthDialog(deviceCode: deviceCode!),
  );

  return ok == true;
}

class _GitHubDeviceAuthDialog extends ConsumerStatefulWidget {
  const _GitHubDeviceAuthDialog({required this.deviceCode});

  final GitHubDeviceCode deviceCode;

  @override
  ConsumerState<_GitHubDeviceAuthDialog> createState() =>
      _GitHubDeviceAuthDialogState();
}

class _GitHubDeviceAuthDialogState
    extends ConsumerState<_GitHubDeviceAuthDialog> {
  var _cancelled = false;
  String? _error;
  String? _login;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    try {
      final session =
          await ref.read(githubAuthControllerProvider).completeDeviceFlow(
                deviceCode: widget.deviceCode,
                onWaiting: (remaining) {
                  if (!mounted) return;
                  setState(() => _remaining = remaining);
                },
                isCancelled: () => _cancelled,
              );
      if (!mounted) return;
      setState(() => _login = session.login);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, true);
    } on GitHubDeviceAuthException catch (e) {
      if (!mounted || _cancelled) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.deviceCode.userCode;
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    return AlertDialog(
      title: const Text('Вход через GitHub'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'В браузере подтвердите доступ. Если страница не открылась — перейдите на github.com/login/device и введите код:',
          ),
          const SizedBox(height: 12),
          SelectableText(
            code,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Код скопирован')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Скопировать код'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: MeshPadColors.danger)),
          ] else if (_login != null) ...[
            const SizedBox(height: 8),
            Text('Подключено как $_login'),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ожидание подтверждения… '
                    '${minutes.toString().padLeft(2, '0')}:'
                    '${seconds.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.pop(context, false);
          },
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
