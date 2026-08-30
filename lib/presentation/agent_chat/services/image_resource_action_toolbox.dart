import '../../../core/agent/agent_types.dart';
import 'defined_agent_tool.dart';
import 'image_resource_action_service.dart';
import 'toolbox_json.dart';

/// Mutation/external-action tools for stable generated-image references.
///
/// Registration and permission policy intentionally remain outside this
/// toolbox so the application registry can grant each action explicitly.
final class ImageResourceActionToolbox {
  ImageResourceActionToolbox(this.service);

  final ImageResourceActionService service;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'save_generated_image',
      label: 'Save Generated Image',
      description:
          'Save a generated image resource to one explicit safe file target. '
          'Pass the stable generated-image resource_ref first and a complete '
          'destination_path. The target must be within the configured file '
          'scope, have a matching image extension, and must not already exist.',
      parameters: toolboxObject(
        properties: {
          'resource_ref': {'type': 'object'},
          'destination_path': {
            'type': 'string',
            'description':
                'Explicit workspace-relative or permitted absolute file target.',
          },
        },
        required: const ['resource_ref', 'destination_path'],
      ),
      executionModeOverride: ToolExecutionMode.sequential,
      executeFn: (_, args) => service.save(args),
    ),
    DefinedAgentTool(
      name: 'copy_generated_image_to_clipboard',
      label: 'Copy Generated Image to Clipboard',
      description:
          'Copy a stable generated-image resource_ref to the system image '
          'clipboard. This performs an external mutation.',
      parameters: toolboxObject(
        properties: {
          'resource_ref': {'type': 'object'},
        },
        required: const ['resource_ref'],
      ),
      executionModeOverride: ToolExecutionMode.sequential,
      executeFn: (_, args) => service.copy(args),
    ),
    DefinedAgentTool(
      name: 'send_generated_image_to_krita',
      label: 'Send Generated Image to Krita',
      description:
          'Send a stable generated-image resource_ref through the configured '
          'Krita Bridge. Platform support, bridge configuration, and an '
          'authenticated client connection are required.',
      parameters: toolboxObject(
        properties: {
          'resource_ref': {'type': 'object'},
        },
        required: const ['resource_ref'],
      ),
      executionModeOverride: ToolExecutionMode.sequential,
      executeFn: (_, args) => service.sendKrita(args),
    ),
  ];
}
