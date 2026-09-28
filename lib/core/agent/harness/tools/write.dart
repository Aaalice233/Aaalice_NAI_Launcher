import '../../agent_types.dart';
import '../harness_types.dart';
import 'file_mutation_queue.dart';
import 'path_utils.dart';


class WriteHarnessTool extends AgentHarnessTool {
  WriteHarnessTool()
    : super(
        name: 'write',
        label: 'write',
        description:
            'Write content to a file. Creates the file if it doesn\'t exist, '
            'overwrites if it does. Automatically creates parent directories.',
        parameters: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description':
                  'Path to the file to write (relative or absolute)',
            },
            'content': {
              'type': 'string',
              'description': 'Content to write to the file',
            },
          },
          'required': ['path', 'content'],
        },
      );

  @override
  Future<AgentToolResult> executeWithContext(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
    dynamic context,
  ]) async {
    final env = (context as ExecutionToolContext).env;
    final path = params['path'] as String;
    final content = params['content'] as String;

    final absolutePath = await resolveToolPath(env, path, signal);
    return withFileMutationQueue(env, absolutePath, () async {
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }
      getOrThrow(await env.writeFile(absolutePath, content, signal));
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }
      return AgentToolResult(
        content: [
          ToolResultTextContent(
            'Successfully wrote ${content.length} bytes to $path',
          ),
        ],
        details: null,
      );
    });
  }
}

AgentHarnessTool createWriteTool() {
  return WriteHarnessTool();
}
