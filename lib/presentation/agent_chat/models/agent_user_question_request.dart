import '../../../data/models/interaction/user_question.dart';

class AgentUserQuestionRequest {
  const AgentUserQuestionRequest({
    required this.toolCallId,
    required this.questions,
    this.expiresAt,
  });

  final DateTime? expiresAt;
  final String toolCallId;
  final List<UserQuestion> questions;
}
