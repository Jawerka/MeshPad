import 'package:flutter/material.dart';

import '../../core/theme/meshpad_colors.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.peerId,
    required this.icon,
    required this.accent,
    this.trailing,
    this.footer,
    this.onAvatarTap,
    this.compact = false,
  });

  final String name;
  final String subtitle;
  final String peerId;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onAvatarTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      backgroundColor: accent.withValues(alpha: 0.22),
      child: Icon(icon, color: accent),
    );

    if (compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  onAvatarTap == null
                      ? avatar
                      : InkWell(
                          onTap: onAvatarTap,
                          customBorder: const CircleBorder(),
                          child: avatar,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MeshPadColors.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                footer!,
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: onAvatarTap == null
            ? avatar
            : InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: avatar,
              ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
