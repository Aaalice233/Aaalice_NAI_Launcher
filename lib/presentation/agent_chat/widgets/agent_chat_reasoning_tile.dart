import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';

class AgentChatReasoningTile extends StatefulWidget {
  const AgentChatReasoningTile({
    super.key,
    required this.thinking,
    this.live = false,
  });

  final String thinking;
  final bool live;

  @override
  State<AgentChatReasoningTile> createState() => _AgentChatReasoningTileState();
}

class _AgentChatReasoningTileState extends State<AgentChatReasoningTile> {
  late bool _expanded;
  bool _userOverrodeExpansion = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.live;
  }

  @override
  void didUpdateWidget(covariant AgentChatReasoningTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userOverrodeExpansion && oldWidget.live != widget.live) {
      _expanded = widget.live;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            key: const ValueKey('agent-reasoning-toggle'),
            onTap: () {
              setState(() {
                _userOverrodeExpansion = true;
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: context.interactionPolicy.minimumControlExtent,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      widget.live
                          ? Icons.hourglass_top_rounded
                          : Icons.psychology_alt_outlined,
                      size: 16,
                      color: widget.live
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.agentChat_reasoning,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
            child: SelectableText(
              widget.thinking,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
