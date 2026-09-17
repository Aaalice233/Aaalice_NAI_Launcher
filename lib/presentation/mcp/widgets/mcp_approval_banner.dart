import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../agent_chat/widgets/agent_chat_approval.dart';
import '../../themes/core/layered_surface_style.dart';
import '../providers/mcp_server_notifier.dart';
import '../services/mcp_approval_coordinator.dart';

const double _bannerMaxWidth = 760;
const EdgeInsets _bannerPadding = EdgeInsets.fromLTRB(12, 8, 12, 0);

/// 挂在 shell Stack 最上层：侧边面板打开时仍能裁决；无待授权时尺寸为零，不拦截指针。
class McpApprovalOverlay extends StatelessWidget {
  const McpApprovalOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _bannerMaxWidth + _bannerPadding.horizontal,
              maxHeight: constraints.maxHeight * 0.45,
            ),
            child: const SingleChildScrollView(
              primary: false,
              child: McpApprovalBanner(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 外部 MCP 调用的授权卡片，由 [McpApprovalOverlay] 浮在页面之上，不挤占布局。
class McpApprovalBanner extends ConsumerWidget {
  const McpApprovalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!PlatformCapabilities.current.supportsMcpServer) {
      return const SizedBox.shrink();
    }
    final pending = ref.watch(
      mcpServerNotifierProvider.select((state) => state.pendingApproval),
    );
    if (pending == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final clientLabel = pending.clientLabel.trim().isEmpty
        ? context.l10n.mcpApproval_unknownClient
        : pending.clientLabel.trim();

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: _bannerPadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _bannerMaxWidth),
            child: Material(
              key: const ValueKey('mcp-approval-banner'),
              color: overlaySurfaceColor(colorScheme),
              elevation: 4,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                container: true,
                child: _McpApprovalBannerBody(
                  pending: pending,
                  clientLabel: clientLabel,
                  onResolve: (approved) => ref
                      .read(mcpServerNotifierProvider.notifier)
                      .resolveApproval(pending.toolCallId, approved),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _McpApprovalBannerBody extends StatefulWidget {
  const _McpApprovalBannerBody({
    required this.pending,
    required this.clientLabel,
    required this.onResolve,
  });

  final McpApprovalRequest pending;
  final String clientLabel;
  final void Function(bool approved) onResolve;

  @override
  State<_McpApprovalBannerBody> createState() => _McpApprovalBannerBodyState();
}

class _McpApprovalBannerBodyState extends State<_McpApprovalBannerBody> {
  Timer? _ticker;
  late int _remainingSeconds = _secondsLeft();

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(_McpApprovalBannerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pending.expiresAt != widget.pending.expiresAt) {
      _remainingSeconds = _secondsLeft();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _secondsLeft();
      if (next == _remainingSeconds) return;
      setState(() => _remainingSeconds = next);
    });
  }

  int _secondsLeft() {
    final left = widget.pending.expiresAt.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.mcpApproval_title(widget.clientLabel),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AgentChatApprovalCard(
            toolName: widget.pending.request.toolName,
            args: widget.pending.request.args,
            estimatedAnlas: widget.pending.request.estimatedAnlas,
            fileTargets: widget.pending.request.fileTargets,
            onResolve: widget.onResolve,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              l10n.mcpApproval_expiresIn(_remainingSeconds),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
