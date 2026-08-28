import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/validate_tool_arguments.dart';

void main() {
  const tool = _BoundedTool();

  test('validates JSON Schema minimum and maximum', () {
    expect(
      () => validateToolArguments(
        tool,
        const ToolCallContent(
          id: 'below',
          name: 'bounded',
          arguments: {'value': 0},
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => validateToolArguments(
        tool,
        const ToolCallContent(
          id: 'above',
          name: 'bounded',
          arguments: {'value': 11},
        ),
      ),
      throwsFormatException,
    );
    expect(
      validateToolArguments(
        tool,
        const ToolCallContent(
          id: 'valid',
          name: 'bounded',
          arguments: {'value': 5},
        ),
      ),
      {'value': 5},
    );
  });
}

class _BoundedTool extends AgentTool {
  const _BoundedTool()
    : super(
        name: 'bounded',
        label: 'Bounded',
        description: 'Test tool',
        parameters: const {
          'type': 'object',
          'properties': {
            'value': {'type': 'number', 'minimum': 1, 'maximum': 10},
          },
          'required': ['value'],
        },
      );

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    return AgentToolResult(content: const [], details: const {});
  }
}
