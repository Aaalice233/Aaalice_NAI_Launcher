import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/common/model_family_icon.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_approval.dart';
import 'agent_chat_panel_view_data.dart';

class AgentChatStatus extends StatelessWidget {
  const AgentChatStatus({
    super.key,
    required this.viewData,
    required this.commands,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final state = viewData.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.retryStatus case final retryStatus?)
          AgentChatRetryNotice(status: retryStatus),
        if (state.error.isNotEmpty)
          _AgentChatErrorCard(
            error: state.error,
            retryAttempts: state.errorRetryAttempts,
            canRetry:
                state.status != AgentChatRunStatus.running &&
                state.messages.any((message) => message is UserMessage),
            onDismiss: commands.dismissError,
            onRetry: commands.retryLastMessage,
          ),
        if (state.compacting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                Icon(
                  Icons.compress_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.agentChat_compacting,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        if (state.approvalRequest case final request?)
          AgentChatApprovalCard(
            key: ValueKey(request.toolCallId),
            toolName: request.toolName,
            args: request.args,
            estimatedAnlas: request.estimatedAnlas,
            fileTargets: request.fileTargets,
            onResolve: (approved) =>
                commands.resolveApproval(request.toolCallId, approved),
          ),
      ],
    );
  }
}

final _httpStatusPattern = RegExp(
  r'(?:HTTP(?: status)?[: ]+|status code of )(\d{3})',
  caseSensitive: false,
);
final _networkErrorPattern = RegExp(r'network.?error', caseSensitive: false);

/// 能归类的请求失败给出本地化摘要，归不了类返回 null。
String? _requestFailureSummary(BuildContext context, String error) {
  if (_httpStatusPattern.firstMatch(error) case final match?) {
    return context.l10n.networkError_requestFailed(int.parse(match.group(1)!));
  }
  if (_networkErrorPattern.hasMatch(error)) {
    return context.l10n.networkError_connection;
  }
  return null;
}

/// 自动重试退避期间的提示；最终失败时由错误卡片接替。
class AgentChatRetryNotice extends StatefulWidget {
  const AgentChatRetryNotice({super.key, required this.status});

  final AgentChatRetryStatus status;

  @override
  State<AgentChatRetryNotice> createState() => _AgentChatRetryNoticeState();
}

class _AgentChatRetryNoticeState extends State<AgentChatRetryNotice> {
  Timer? _ticker;

  int get _remainingSeconds {
    final remainingMs =
        widget.status.resumesAtMs - DateTime.now().millisecondsSinceEpoch;
    return remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant AgentChatRetryNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.status, widget.status)) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_remainingSeconds == 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_remainingSeconds == 0) {
        timer.cancel();
        _ticker = null;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final status = widget.status;
    final seconds = _remainingSeconds;
    final title = seconds > 0
        ? l10n.agentChat_autoRetryCountdown(
            status.attempt,
            status.maxAttempts,
            seconds,
          )
        : l10n.agentChat_autoRetryStarting(status.attempt, status.maxAttempts);
    final reason =
        _requestFailureSummary(context, status.errorMessage) ??
        status.errorMessage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalMargin = constraints.maxWidth < 600 ? 12.0 : 10.0;
        return Container(
          key: const ValueKey('agent-chat-retry-notice'),
          margin: EdgeInsets.fromLTRB(horizontalMargin, 4, horizontalMargin, 4),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    value: MediaQuery.disableAnimationsOf(context)
                        ? 0.75
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const ValueKey('agent-chat-retry-notice-title'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      key: const ValueKey('agent-chat-retry-notice-reason'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgentChatErrorCard extends StatefulWidget {
  const _AgentChatErrorCard({
    required this.error,
    required this.retryAttempts,
    required this.canRetry,
    required this.onDismiss,
    required this.onRetry,
  });

  final String error;
  final int retryAttempts;
  final bool canRetry;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  @override
  State<_AgentChatErrorCard> createState() => _AgentChatErrorCardState();
}

class _AgentChatErrorCardState extends State<_AgentChatErrorCard> {
  bool _detailsExpanded = false;

  String _summary(BuildContext context) =>
      _requestFailureSummary(context, widget.error) ??
      context.l10n.agentChat_requestFailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final foreground = theme.colorScheme.onErrorContainer;
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 600;
        return Container(
          key: const ValueKey('agent-chat-error-card'),
          margin: EdgeInsets.fromLTRB(
            compactLayout ? 12 : 10,
            4,
            compactLayout ? 12 : 10,
            4,
          ),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _summary(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    key: const ValueKey('agent-chat-error-dismiss'),
                    width: controlExtent,
                    height: controlExtent,
                    child: InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(8),
                      child: Icon(
                        Icons.close,
                        size: context.interactionPolicy.touchAvailable
                            ? 18
                            : 14,
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.retryAttempts > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 8, 2),
                  child: Text(
                    l10n.agentChat_autoRetryExhausted(widget.retryAttempts),
                    key: const ValueKey('agent-chat-error-retry-attempts'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              if (_detailsExpanded)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(26, 4, 8, 4),
                    child: SelectableText(
                      widget.error,
                      key: const ValueKey('agent-chat-error-details'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    key: const ValueKey('agent-chat-error-details-toggle'),
                    onPressed: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    icon: Icon(
                      _detailsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 17,
                    ),
                    label: Text(l10n.agentChat_errorDetails),
                  ),
                  if (widget.canRetry)
                    TextButton.icon(
                      key: const ValueKey('agent-chat-error-retry'),
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(l10n.common_retry),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AgentChatWorkStatus extends StatelessWidget {
  const AgentChatWorkStatus({
    super.key,
    required this.phase,
    required this.routeLabel,
  });

  final AgentChatWorkPhase phase;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalMargin = constraints.maxWidth < 600 ? 12.0 : 10.0;
        return Container(
          key: const ValueKey('agent-chat-work-status'),
          margin: EdgeInsets.fromLTRB(horizontalMargin, 4, horizontalMargin, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: phase == AgentChatWorkPhase.failed
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.24)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _phaseIcon(phase),
                size: 16,
                color: phase == AgentChatWorkPhase.failed
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phaseLabel(context, phase),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (routeLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      ModelNameLabel(
                        modelId: routeLabel,
                        iconSize: 14,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.62,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _phaseLabel(BuildContext context, AgentChatWorkPhase phase) =>
      switch (phase) {
        AgentChatWorkPhase.preparing => context.l10n.agentChat_phasePreparing,
        AgentChatWorkPhase.thinking => context.l10n.agentChat_thinking,
        AgentChatWorkPhase.responding => context.l10n.agentChat_phaseResponding,
        AgentChatWorkPhase.usingTools => context.l10n.agentChat_toolRunning,
        AgentChatWorkPhase.awaitingApproval =>
          context.l10n.agentChat_phaseAwaitingApproval,
        AgentChatWorkPhase.compacting => context.l10n.agentChat_compacting,
        AgentChatWorkPhase.retrying => context.l10n.common_retry,
        AgentChatWorkPhase.stopping => context.l10n.agentChat_phaseStopping,
        AgentChatWorkPhase.failed => context.l10n.common_error,
        AgentChatWorkPhase.idle => '',
      };

  IconData _phaseIcon(AgentChatWorkPhase phase) => switch (phase) {
    AgentChatWorkPhase.preparing => Icons.hourglass_top_rounded,
    AgentChatWorkPhase.thinking => Icons.psychology_alt_outlined,
    AgentChatWorkPhase.responding => Icons.edit_note_rounded,
    AgentChatWorkPhase.usingTools => Icons.build_circle_outlined,
    AgentChatWorkPhase.awaitingApproval => Icons.gpp_maybe_outlined,
    AgentChatWorkPhase.compacting => Icons.compress_rounded,
    AgentChatWorkPhase.retrying => Icons.refresh_rounded,
    AgentChatWorkPhase.stopping => Icons.stop_circle_outlined,
    AgentChatWorkPhase.failed => Icons.error_outline_rounded,
    AgentChatWorkPhase.idle => Icons.circle_outlined,
  };
}
