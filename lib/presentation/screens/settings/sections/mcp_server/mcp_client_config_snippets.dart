import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/community_links.dart';
import '../../../../../core/mcp/cli/mcp_client_config_printer.dart';
import '../../../../../core/mcp/mcp_cli_path.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../themes/core/layered_surface_style.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/app_toast.dart';

const String _previewTokenMask = '••••';
const String _docsUrl = '${CommunityLinks.github}/blob/main/docs/mcp_server.md';

/// 每个 MCP 客户端一段可直接粘贴的配置；预览打码，复制时才写入真实令牌。
class McpClientConfigSnippets extends ConsumerStatefulWidget {
  const McpClientConfigSnippets({super.key, required this.endpoint});

  final Uri endpoint;

  @override
  ConsumerState<McpClientConfigSnippets> createState() =>
      _McpClientConfigSnippetsState();
}

class _McpClientConfigSnippetsState
    extends ConsumerState<McpClientConfigSnippets> {
  late final String _cliPath = resolveBundledMcpCliPath();
  late final bool _cliExists = bundledMcpCliExists();

  Future<void> _copyConfig(McpClientKind kind) async {
    final token = await ref
        .read(mcpServerNotifierProvider.notifier)
        .readToken();
    if (!mounted) return;
    await Clipboard.setData(
      ClipboardData(
        text: renderMcpClientConfig(
          kind,
          endpoint: widget.endpoint,
          token: token,
          cliPath: _cliPath,
        ),
      ),
    );
    if (!mounted) return;
    AppToast.success(context, context.l10n.common_copied);
  }

  Future<void> _openDocs() async {
    final uri = Uri.parse(_docsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in McpClientKind.values)
          _ClientPanel(
            kind: kind,
            preview: renderMcpClientConfig(
              kind,
              endpoint: widget.endpoint,
              token: _previewTokenMask,
              cliPath: _cliPath,
            ),
            showCliWarning: kind == McpClientKind.claudeDesktop && !_cliExists,
            cliPath: _cliPath,
            onCopy: () => _copyConfig(kind),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spacingXs,
            DesignTokens.spacingXxs,
            DesignTokens.spacingXs,
            0,
          ),
          child: Text(
            l10n.settings_mcpServerTokenMaskNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('mcp-server-view-docs'),
            onPressed: _openDocs,
            icon: const Icon(
              Icons.menu_book_outlined,
              size: DesignTokens.iconSm,
            ),
            label: Text(l10n.settings_mcpServerViewDocs),
          ),
        ),
      ],
    );
  }
}

class _ClientPanel extends StatelessWidget {
  const _ClientPanel({
    required this.kind,
    required this.preview,
    required this.showCliWarning,
    required this.cliPath,
    required this.onCopy,
  });

  final McpClientKind kind;
  final String preview;
  final bool showCliWarning;
  final String cliPath;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ExpansionTile(
      key: ValueKey('mcp-server-client-config-${kind.cliName}'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingXs,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(_displayName(kind)),
      children: [
        Text(
          _instruction(context, kind),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingXs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: controlSurfaceColor(theme.colorScheme),
            borderRadius: BorderRadius.circular(DesignTokens.spacingXs),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingSm),
            child: SelectableText(
              preview,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        if (showCliWarning) ...[
          const SizedBox(height: DesignTokens.spacingXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_outlined,
                  size: DesignTokens.iconSm,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: DesignTokens.spacingXs),
              Expanded(
                child: Text(
                  l10n.settings_mcpServerCliMissing(cliPath),
                  key: const ValueKey('mcp-server-cli-missing'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: ValueKey('mcp-server-copy-config-${kind.cliName}'),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: DesignTokens.iconSm),
            label: Text(l10n.settings_mcpServerCopyConfig),
          ),
        ),
      ],
    );
  }
}

String _displayName(McpClientKind kind) {
  return switch (kind) {
    McpClientKind.claudeCode => 'Claude Code',
    McpClientKind.codex => 'Codex CLI',
    McpClientKind.cursor => 'Cursor',
    McpClientKind.claudeDesktop => 'Claude Desktop',
  };
}

String _instruction(BuildContext context, McpClientKind kind) {
  final l10n = context.l10n;
  return switch (kind) {
    McpClientKind.claudeCode => l10n.settings_mcpServerClaudeCodeHint,
    McpClientKind.codex => l10n.settings_mcpServerCodexHint,
    McpClientKind.cursor => l10n.settings_mcpServerCursorHint,
    McpClientKind.claudeDesktop => l10n.settings_mcpServerClaudeDesktopHint,
  };
}
