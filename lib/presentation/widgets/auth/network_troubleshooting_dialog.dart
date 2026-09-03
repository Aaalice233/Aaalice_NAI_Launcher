import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../adaptive/adaptive_presenter.dart';

/// 提供常见网络问题解决方案的自适应帮助面板。
class NetworkTroubleshootingDialog extends StatelessWidget {
  const NetworkTroubleshootingDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      sideSheetWidth: 498,
      titleBuilder: (context) {
        final theme = Theme.of(context);
        return Row(
          children: [
            Icon(Icons.wifi_find, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.api_error_network,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        );
      },
      builder: (context, scrollController) =>
          NetworkTroubleshootingDialog(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('network-troubleshooting-tips-list'),
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.8),
            child: SingleChildScrollView(
              key: const Key('network-troubleshooting-actions-scroll'),
              primary: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_close),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        Icon(icon, size: 20, color: theme.colorScheme.primary),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
