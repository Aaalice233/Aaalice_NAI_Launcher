import '../../../core/agent/agent_types.dart';
import 'defined_agent_tool.dart';
import 'manual_inpaint_toolbox_serialization.dart';

typedef ManualInpaintToolHandler =
    Future<AgentToolResult> Function(Map<String, dynamic> arguments);

List<AgentTool> buildManualInpaintToolDefinitions({
  required ManualInpaintToolHandler create,
  required ManualInpaintToolHandler list,
  required ManualInpaintToolHandler get,
  required ManualInpaintToolHandler cancel,
  required ManualInpaintToolHandler reEdit,
  required ManualInpaintToolHandler submit,
}) => [
  DefinedAgentTool(
    name: 'create_manual_inpaint_draft',
    label: 'Create Manual Inpaint Draft',
    description:
        'Persist an inpaint source, prompt, and generation parameter snapshot, '
        'then open the existing image editor for the user. Returns immediately '
        'without waiting for editing. Poll get_manual_inpaint_draft until the '
        'status is ready or cancelled.',
    parameters: const {
      'type': 'object',
      'properties': {
        'source_image': {'type': 'string'},
        'source_ref': {'type': 'object'},
        'prompt': {'type': 'string'},
        'params': {'type': 'object'},
      },
      'required': ['prompt'],
    },
    executeFn: (_, arguments) => create(arguments),
  ),
  DefinedAgentTool(
    name: 'list_manual_inpaint_drafts',
    label: 'List Manual Inpaint Drafts',
    description: 'List persisted manual inpaint drafts, newest update first.',
    parameters: const {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
      },
    },
    executeFn: (_, arguments) => list(arguments),
  ),
  DefinedAgentTool(
    name: 'get_manual_inpaint_draft',
    label: 'Get Manual Inpaint Draft',
    description: 'Read the latest persisted state of a manual inpaint draft.',
    parameters: manualInpaintDraftIdSchema,
    executeFn: (_, arguments) => get(arguments),
  ),
  DefinedAgentTool(
    name: 'cancel_manual_inpaint_draft',
    label: 'Cancel Manual Inpaint Draft',
    description:
        'Cancel a prepared or editing draft and close its editor session.',
    parameters: manualInpaintDraftIdSchema,
    executeFn: (_, arguments) => cancel(arguments),
  ),
  DefinedAgentTool(
    name: 'reedit_manual_inpaint_draft',
    label: 'Re-edit Manual Inpaint Draft',
    description:
        'Reopen a ready, cancelled, submitted, or failed draft in the existing '
        'image editor. A submitted draft is copied to a new draft ID.',
    parameters: manualInpaintDraftIdSchema,
    executeFn: (_, arguments) => reEdit(arguments),
  ),
  DefinedAgentTool(
    name: 'submit_manual_inpaint_draft',
    label: 'Submit Manual Inpaint Draft',
    description:
        'Submit a ready draft through the real application generation provider. '
        'This can spend Anlas and always requires explicit user approval.',
    parameters: const {
      'type': 'object',
      'properties': {
        'draft_id': {'type': 'string'},
        'confirm': {'type': 'boolean'},
      },
      'required': ['draft_id', 'confirm'],
    },
    executeFn: (_, arguments) => submit(arguments),
  ),
];
