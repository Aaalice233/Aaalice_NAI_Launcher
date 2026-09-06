import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_chat_notifier.dart';
import '../models/agent_user_question_request.dart';
import '../../widgets/common/user_question_flow.dart';

class AgentChatQuestionCard extends ConsumerWidget {
  const AgentChatQuestionCard({super.key, required this.request});

  final AgentUserQuestionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) => UserQuestionFlow(
    key: ValueKey(request.toolCallId),
    questions: request.questions,
    expiresAt: request.expiresAt,
    onSubmit: (answers) => ref
        .read(agentChatNotifierProvider.notifier)
        .resolveUserQuestions(request.toolCallId, answers),
    onCancel: () => ref
        .read(agentChatNotifierProvider.notifier)
        .resolveUserQuestions(request.toolCallId, null),
  );
}
