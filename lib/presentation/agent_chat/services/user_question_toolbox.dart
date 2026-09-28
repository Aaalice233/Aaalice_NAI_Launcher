import '../../../core/agent/agent_types.dart';
import '../../../data/models/interaction/user_question.dart';
import 'agent_user_question_controller.dart';
import '../models/agent_user_question_request.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

class UserQuestionToolbox {
  UserQuestionToolbox(this.controller);
  final AgentUserQuestionController controller;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'ask_user_question',
      label: 'Ask User Question',
      description:
          'Ask one or more structured questions when missing preferences or '
          'ambiguity materially changes the task. Provide exactly three distinct, '
          'feasible directions per question, each with a concise explanation. '
          'Recommend exactly one by recommended_option_id. The UI adds a fourth '
          'custom-text option; do not supply Other/custom/filler options yourself. '
          'The user answers sequentially and submits all answers together. '
          'After timeout_seconds (default 120), all recommended options are '
          'automatically submitted with source timeout_recommendation. '
          'Do not use this tool for permission or payment approval, or to ask '
          'for facts available through research tools. Cancellation is not consent.',
      executionModeOverride: ToolExecutionMode.sequential,
      parameters: toolboxObject(
        properties: {
          'timeout_seconds': {
            'type': ['integer', 'null'],
            'minimum': 1,
            'description':
                'Whole request timeout in seconds; null defaults to 120.',
          },
          'questions': {
            'type': 'array',
            'minItems': 1,
            'items': toolboxObject(
              properties: {
                'id': {'type': 'string', 'minLength': 1},
                'title': {'type': 'string', 'minLength': 1},
                'recommended_option_id': {'type': 'string', 'minLength': 1},
                'options': {
                  'type': 'array',
                  'minItems': 3,
                  'maxItems': 3,
                  'items': toolboxObject(
                    properties: {
                      'id': {'type': 'string', 'minLength': 1},
                      'label': {'type': 'string', 'minLength': 1},
                      'description': {'type': 'string', 'minLength': 1},
                    },
                    required: ['id', 'label', 'description'],
                  ),
                },
              },
              required: ['id', 'title', 'options', 'recommended_option_id'],
            ),
          },
        },
        required: ['questions'],
      ),
      executeWithControl: (id, params, signal, _) async {
        final List<UserQuestion> questions;
        final timeout = params['timeout_seconds'] ?? 120;
        if (timeout is! int || timeout <= 0) {
          return agentToolError(
            'invalid_questions',
            'timeout_seconds must be a positive integer.',
          );
        }
        try {
          final raw = params['questions'];
          if (raw is! List || raw.isEmpty) {
            throw const FormatException('At least one question is required.');
          }
          questions = raw
              .map((value) {
                if (value is! Map<String, dynamic>) {
                  throw const FormatException('Invalid question.');
                }
                return UserQuestion.fromJson(value);
              })
              .toList(growable: false);
          if (questions.map((question) => question.id).toSet().length !=
              questions.length) {
            throw const FormatException('Question IDs must be distinct.');
          }
        } on FormatException catch (error) {
          return agentToolError('invalid_questions', error.message);
        }
        final answers = await controller.ask(
          AgentUserQuestionRequest(
            toolCallId: id,
            questions: List.unmodifiable(questions),
          ),
          signal,
          timeout: Duration(seconds: timeout),
        );
        return agentToolJsonResult({
          'cancelled': answers == null,
          'answers': [
            if (answers != null)
              for (var i = 0; i < questions.length; i++)
                answers[i].toJson(questions[i]),
          ],
        });
      },
    ),
  ];
}
