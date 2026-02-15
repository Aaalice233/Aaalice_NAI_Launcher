import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';

/// 网络故障排除对话框
///
/// 提供常见的网络问题解决方案提示
class NetworkTroubleshootingDialog extends StatelessWidget {
  const NetworkTroubleshootingDialog({super.key});

  /// 显示对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const NetworkTroubleshootingDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.wifi_find,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(l10n.api_error_network),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipItem(
              context,
              icon: Icons.check_circle_outline,
              title: l10n.auth_troubleshoot_checkConnection_title,
              description: l10n.auth_troubleshoot_checkConnection_desc,
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context,
              icon: Icons.refresh,
              title: l10n.auth_troubleshoot_retry_title,
              description: l10n.auth_troubleshoot_retry_desc,
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context,
              icon: Icons.vpn_lock,
              title: l10n.auth_troubleshoot_proxy_title,
              description: l10n.auth_troubleshoot_proxy_desc,
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context,
              icon: Icons.security,
              title: l10n.auth_troubleshoot_firewall_title,
              description: l10n.auth_troubleshoot_firewall_desc,
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context,
              icon: Icons.cloud_off,
              title: l10n.auth_troubleshoot_serverStatus_title,
              description: l10n.auth_troubleshoot_serverStatus_desc,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_close),
        ),
      ],
    );
  }

  /// 构建提示项
  Widget _buildTipItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
