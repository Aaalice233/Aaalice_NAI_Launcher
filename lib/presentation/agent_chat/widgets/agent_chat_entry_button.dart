import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../providers/agent_chat_notifier.dart';

/// Keeps background conversation progress visible when the workspace is closed.
class AgentChatEntryButton extends ConsumerWidget {
  const AgentChatEntryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      agentChatNotifierProvider.select(
        (state) => (
          running:
              state.status == AgentChatRunStatus.running || state.compacting,
          compacting: state.compacting,
          approval: state.approvalRequest != null,
          question: state.questionRequest != null,
          error: state.error.isNotEmpty,
        ),
      ),
    );
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final status = state.question
        ? l10n.userQuestion_waiting
        : state.approval
        ? l10n.agentChat_phaseAwaitingApproval
        : state.compacting
        ? l10n.agentChat_compacting
        : state.running
        ? l10n.agentChat_phaseResponding
        : state.error
        ? l10n.common_error
        : null;
    final icon = state.question
        ? Icon(
            Icons.help_rounded,
            key: const ValueKey('agent-chat-entry-question'),
            color: colors.primary,
          )
        : state.approval
        ? Icon(Icons.pending_actions_rounded, color: colors.primary)
        : state.running
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              key: const ValueKey('agent-chat-entry-running'),
              strokeWidth: 2,
              value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
            ),
          )
        : state.error
        ? Icon(Icons.error_outline_rounded, color: colors.error)
        : const Icon(Icons.smart_toy_outlined);
    return IconButton(
      key: const ValueKey('generation-agent-drawer-action'),
      tooltip: status == null
          ? l10n.agentChat_tab
          : '${l10n.agentChat_tab} · $status',
      onPressed: onPressed,
      icon: icon,
    );
  }
}
