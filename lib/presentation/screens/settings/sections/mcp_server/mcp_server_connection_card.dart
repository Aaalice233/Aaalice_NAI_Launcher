import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/mcp/mcp_server_constants.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/app_toast.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../../../widgets/common/themed_input.dart';
import '../../widgets/settings_card.dart';

const String _tokenMask = '••••••••';

/// MCP 服务器的连接分组：开关、状态、端点、端口与接入令牌。
class McpServerConnectionCard extends ConsumerStatefulWidget {
  const McpServerConnectionCard({super.key});

  @override
  ConsumerState<McpServerConnectionCard> createState() =>
      _McpServerConnectionCardState();
}

class _McpServerConnectionCardState
    extends ConsumerState<McpServerConnectionCard> {
  late final TextEditingController _portController;
  final FocusNode _portFocus = FocusNode();
  late String _appliedPortText;
  bool _portInvalid = false;
  String? _revealedToken;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: '${ref.read(mcpServerNotifierProvider).configuredPort}',
    );
    _appliedPortText = _portController.text;
    _portFocus.addListener(_handlePortFocusChange);
  }

  @override
  void dispose() {
    _portFocus
      ..removeListener(_handlePortFocusChange)
      ..dispose();
    _portController.dispose();
    super.dispose();
  }

  void _handlePortFocusChange() {
    if (_portFocus.hasFocus || !mounted) return;
    _applyPort();
  }

  // 提交和失焦都会触发，同一份文本只处理一次。
  Future<void> _applyPort() async {
    final raw = _portController.text.trim();
    if (raw == _appliedPortText) return;
    _appliedPortText = raw;
    final parsed = int.tryParse(raw);
    final valid =
        parsed != null &&
        parsed >= McpServerDefaults.minPort &&
        parsed <= McpServerDefaults.maxPort;
    if (_portInvalid == valid) setState(() => _portInvalid = !valid);
    if (!valid) return;
    if (parsed == ref.read(mcpServerNotifierProvider).configuredPort) return;
    await ref.read(mcpServerNotifierProvider.notifier).setPort(parsed);
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppToast.success(context, context.l10n.common_copied);
  }

  Future<void> _toggleTokenVisibility() async {
    if (_revealedToken != null) {
      setState(() => _revealedToken = null);
      return;
    }
    final token = await ref
        .read(mcpServerNotifierProvider.notifier)
        .readToken();
    if (!mounted) return;
    setState(() => _revealedToken = token);
  }

  Future<void> _copyToken() async {
    final token = await ref
        .read(mcpServerNotifierProvider.notifier)
        .readToken();
    if (!mounted) return;
    await _copy(token);
  }

  Future<void> _regenerateToken() async {
    final l10n = context.l10n;
    final notifier = ref.read(mcpServerNotifierProvider.notifier);
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: l10n.settings_mcpServerRegenerateTokenTitle,
      content: l10n.settings_mcpServerRegenerateTokenMessage,
      confirmText: l10n.settings_mcpServerRegenerateToken,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.vpn_key_outlined,
    );
    if (!confirmed) return;
    await notifier.regenerateToken();
    if (!mounted) return;
    setState(() => _revealedToken = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(mcpServerNotifierProvider);
    final notifier = ref.read(mcpServerNotifierProvider.notifier);

    ref.listen<int>(
      mcpServerNotifierProvider.select((value) => value.configuredPort),
      (previous, next) {
        if (_portFocus.hasFocus) return;
        _portController.text = '$next';
        _appliedPortText = _portController.text;
        if (_portInvalid) setState(() => _portInvalid = false);
      },
    );

    final endpoint = state.endpoint;
    final discoveryFilePath = state.discoveryFilePath;
    final showDetails = state.enabled || state.status == McpServerStatus.error;

    return SettingsCard(
      title: l10n.settings_integrationConnectionSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('mcp-server-enable-switch'),
            secondary: Icon(_statusIcon(state.status)),
            title: Text(l10n.settings_mcpServerEnable),
            subtitle: Text(_statusText(context, state.status)),
            value: state.enabled,
            onChanged: state.status == McpServerStatus.starting
                ? null
                : notifier.setEnabled,
          ),
          if (showDetails) ...[
            const SizedBox(height: DesignTokens.spacingXs),
            _StatusRow(state: state),
            if (state.isListening && endpoint != null)
              _CopyableValueRow(
                valueKey: const ValueKey('mcp-server-endpoint'),
                copyKey: const ValueKey('mcp-server-copy-endpoint'),
                label: l10n.settings_mcpServerEndpoint,
                value: '$endpoint',
                copyTooltip: l10n.settings_mcpServerCopyEndpoint,
                onCopy: () => _copy('$endpoint'),
              ),
            _PortField(
              controller: _portController,
              focusNode: _portFocus,
              hasError: _portInvalid,
              onSubmitted: _applyPort,
            ),
            if (discoveryFilePath != null)
              _ValueRow(
                valueKey: const ValueKey('mcp-server-discovery-file'),
                label: l10n.settings_mcpServerDiscoveryFile,
                value: discoveryFilePath,
              ),
            _TokenRow(
              token: _revealedToken,
              onToggleVisibility: _toggleTokenVisibility,
              onCopy: _copyToken,
              onRegenerate: _regenerateToken,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final McpServerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final errorMessage = state.errorMessage;
    final showErrorMessage =
        state.status == McpServerStatus.error &&
        errorMessage != null &&
        errorMessage.isNotEmpty;

    return Padding(
      key: const ValueKey('mcp-server-status'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 12,
              color: _statusColor(theme, state.status),
            ),
          ),
          const SizedBox(width: DesignTokens.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabel(context, state.status)),
                if (showErrorMessage) ...[
                  const SizedBox(height: DesignTokens.spacingXxs),
                  Text(
                    errorMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (state.errorCode == 'port_in_use') ...[
                  const SizedBox(height: DesignTokens.spacingXxs),
                  Text(
                    l10n.settings_mcpServerPortInUseHint(
                      '${state.configuredPort}',
                    ),
                    key: const ValueKey('mcp-server-port-in-use-hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortField extends StatelessWidget {
  const _PortField({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final Future<void> Function() onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_mcpServerPort,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: ThemedInput(
              key: const ValueKey('mcp-server-port-field'),
              controller: controller,
              focusNode: focusNode,
              hasError: hasError,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXxs),
          if (hasError)
            Text(
              l10n.settings_mcpServerPortInvalid(
                '${McpServerDefaults.minPort}',
                '${McpServerDefaults.maxPort}',
              ),
              key: const ValueKey('mcp-server-port-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            Text(
              l10n.settings_mcpServerPortHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.token,
    required this.onToggleVisibility,
    required this.onCopy,
    required this.onRegenerate,
  });

  final String? token;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final revealed = token != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingXxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_mcpServerToken,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.spacingSm),
                  child: SelectableText(
                    token ?? _tokenMask,
                    key: const ValueKey('mcp-server-token'),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('mcp-server-token-reveal'),
                onPressed: onToggleVisibility,
                tooltip: revealed
                    ? l10n.settings_mcpServerHideToken
                    : l10n.settings_mcpServerRevealToken,
                icon: Icon(
                  revealed ? Icons.visibility_off : Icons.visibility_outlined,
                ),
              ),
              IconButton(
                key: const ValueKey('mcp-server-token-copy'),
                onPressed: onCopy,
                tooltip: l10n.settings_mcpServerCopyToken,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('mcp-server-token-regenerate'),
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: DesignTokens.iconSm),
              label: Text(l10n.settings_mcpServerRegenerateToken),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.valueKey,
    required this.label,
    required this.value,
  });

  final Key valueKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXxs),
          SelectableText(value, key: valueKey),
        ],
      ),
    );
  }
}

class _CopyableValueRow extends StatelessWidget {
  const _CopyableValueRow({
    required this.valueKey,
    required this.copyKey,
    required this.label,
    required this.value,
    required this.copyTooltip,
    required this.onCopy,
  });

  final Key valueKey;
  final Key copyKey;
  final String label;
  final String value;
  final String copyTooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.spacingSm),
                  child: SelectableText(value, key: valueKey),
                ),
              ),
              IconButton(
                key: copyKey,
                onPressed: onCopy,
                tooltip: copyTooltip,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusText(BuildContext context, McpServerStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    McpServerStatus.disabled => l10n.settings_mcpServerDisabledText,
    McpServerStatus.starting => l10n.settings_mcpServerStartingText,
    McpServerStatus.listening => l10n.settings_mcpServerListeningText,
    McpServerStatus.error => l10n.settings_mcpServerErrorText,
  };
}

String _statusLabel(BuildContext context, McpServerStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    McpServerStatus.disabled => l10n.settings_mcpServerDisabled,
    McpServerStatus.starting => l10n.settings_mcpServerStarting,
    McpServerStatus.listening => l10n.settings_mcpServerListening,
    McpServerStatus.error => l10n.settings_mcpServerError,
  };
}

IconData _statusIcon(McpServerStatus status) {
  return switch (status) {
    McpServerStatus.disabled => Icons.link_off,
    McpServerStatus.starting => Icons.hourglass_top,
    McpServerStatus.listening => Icons.sensors,
    McpServerStatus.error => Icons.error_outline,
  };
}

Color _statusColor(ThemeData theme, McpServerStatus status) {
  return switch (status) {
    McpServerStatus.disabled => theme.colorScheme.outline,
    McpServerStatus.starting => theme.colorScheme.tertiary,
    McpServerStatus.listening => theme.colorScheme.primary,
    McpServerStatus.error => theme.colorScheme.error,
  };
}
