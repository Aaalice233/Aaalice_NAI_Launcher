import 'package:flutter/material.dart';

import '../../../themes/design_tokens.dart';
import 'mcp_server/mcp_server_clients_card.dart';
import 'mcp_server/mcp_server_connection_card.dart';
import 'mcp_server/mcp_server_permission_card.dart';

/// MCP 服务器设置板块
///
/// 按连接、权限、客户端三组组织；授权裁决仍由全局横幅承担。
class McpServerSettingsSection extends StatelessWidget {
  const McpServerSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McpServerConnectionCard(),
        SizedBox(height: DesignTokens.spacingMd),
        McpServerPermissionCard(),
        SizedBox(height: DesignTokens.spacingMd),
        McpServerClientsCard(),
      ],
    );
  }
}
