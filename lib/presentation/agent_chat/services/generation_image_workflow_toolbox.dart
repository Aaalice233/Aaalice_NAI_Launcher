import '../../../core/agent/agent_types.dart';
import 'defined_agent_tool.dart';
import 'generation_image_workflow_service.dart';

final class GenerationImageWorkflowToolbox {
  const GenerationImageWorkflowToolbox(this.service);

  final GenerationImageWorkflowService service;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'open_generation_image_workflow',
      label: 'Open Generation Image Workflow',
      description:
          'Prepare or open one real application image workflow for a generated '
          'image. This tool only opens UI or prepares controller state; it never '
          'starts generation or spends Anlas. The user must review and explicitly '
          'start any paid operation.',
      parameters: const {
        'type': 'object',
        'properties': {
          'resource_ref': {'type': 'object'},
          'mode': {
            'type': 'string',
            'enum': [
              'edit',
              'inpaint',
              'variations',
              'director',
              'enhance',
              'upscale',
            ],
          },
        },
        'required': ['resource_ref', 'mode'],
        'additionalProperties': false,
      },
      executionModeOverride: ToolExecutionMode.sequential,
      executeFn: (_, args) => service.open(args),
    ),
  ];
}
