import '../../../core/agent/agent_types.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import 'defined_agent_tool.dart';
import 'manual_inpaint_toolbox_serialization.dart';

typedef ManualInpaintToolHandler =
    Future<AgentToolResult> Function(Map<String, dynamic> arguments);

const _sourceSchema = <String, dynamic>{
  'source_image': {'type': 'string'},
  'source_ref': {'type': 'object'},
  'prompt': {'type': 'string'},
  'params': {'type': 'object'},
  'preview': {'type': 'boolean'},
};

List<AgentTool> buildManualInpaintToolDefinitions({
  required ManualInpaintToolHandler create,
  required ManualInpaintToolHandler list,
  required ManualInpaintToolHandler get,
  required ManualInpaintToolHandler cancel,
  required ManualInpaintToolHandler reEdit,
  required ManualInpaintToolHandler submit,
  required ManualInpaintToolHandler createMask,
  required ManualInpaintToolHandler expandCanvas,
  required ManualInpaintToolHandler loadIntoPanel,
}) => [
  DefinedAgentTool(
    name: 'load_inpaint_draft_into_panel',
    label: 'Load Inpaint Draft Into Panel',
    description:
        'Show a ready draft on the Generation page inpaint panel so the user '
        'can review the mask, adjust strength or focused inpainting, or edit '
        'it further before generating. This replaces whatever source image '
        'and mask the page currently holds, so ask first when the user may '
        'have work in progress there. It never generates and never spends '
        'Anlas.',
    parameters: manualInpaintDraftIdSchema,
    executeFn: (_, arguments) => loadIntoPanel(arguments),
  ),
  DefinedAgentTool(
    name: 'create_inpaint_mask',
    label: 'Create Inpaint Mask',
    description:
        'Author an inpaint mask from geometry and store it as a ready draft, '
        'without opening the editor. Read the source image with the read tool '
        'first: coordinates are normalized 0-1 fractions of the image, so they '
        'must come from actually looking at it rather than from its reported '
        'size. Returns an overlay preview; check the mask lands on the target '
        'before calling submit_manual_inpaint_draft, which is what spends '
        'Anlas. Re-authoring a mask is free, so prefer another attempt over '
        'submitting a doubtful one.',
    parameters: const {
      'type': 'object',
      'properties': {
        ..._sourceSchema,
        'regions': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 16,
          'description':
              'Shapes combined in order. Each is {"shape": "rect"|"ellipse", '
              '"left","top","right","bottom"} or {"shape": "rect"|"ellipse", '
              '"x","y","width","height"} or {"shape": "polygon", "points": '
              '[{"x","y"},...]}, all normalized 0-1, plus optional '
              '"mode": "add"|"subtract".',
          'items': {'type': 'object'},
        },
        'expand_ratio': {
          'type': 'number',
          'minimum': 0,
          'maximum': 0.25,
          'description':
              'Grows the mask by this fraction of the shorter side. Useful '
              'margin when the target outline is uncertain.',
        },
        'focused': {
          'description':
              'auto (default), true, or false. Focused inpainting crops around '
              'the mask and upscales it, which is what makes small targets '
              'such as hands come back detailed. auto turns it on only for '
              'sources above the 1 MP free-generation size, where repainting '
              'the whole frame would either cost Anlas or shrink the target. '
              'On a 1 MP or smaller source, pass true explicitly when the '
              'target is small, such as a hand or a face.',
        },
        'context_padding': {
          'type': 'integer',
          'minimum': FocusedInpaintUtils.minContextPadding,
          'maximum': FocusedInpaintUtils.maxContextPadding,
          'description':
              'Pixels of surrounding context kept on each side when focused '
              'inpainting is used. Larger blends better but lowers the '
              'effective resolution of the repainted area.',
        },
      },
      'required': ['regions', 'prompt'],
    },
    executeFn: (_, arguments) => createMask(arguments),
  ),
  DefinedAgentTool(
    name: 'expand_inpaint_canvas',
    label: 'Expand Inpaint Canvas',
    description:
        'Outpaint: grow the canvas by the given pixel margins and store the '
        'expanded image plus its generated mask as a ready draft. Needs no '
        'visual targeting because the new area is exactly the added margins. '
        'Submit with submit_manual_inpaint_draft when the preview looks right.',
    parameters: const {
      'type': 'object',
      'properties': {
        ..._sourceSchema,
        'edges': {
          'type': 'object',
          'description':
              'Pixels to add on each side: {"left","top","right","bottom"}. '
              'Omitted sides default to 0; at least one must be positive.',
          'properties': {
            'left': {'type': 'integer', 'minimum': 0, 'maximum': 4096},
            'top': {'type': 'integer', 'minimum': 0, 'maximum': 4096},
            'right': {'type': 'integer', 'minimum': 0, 'maximum': 4096},
            'bottom': {'type': 'integer', 'minimum': 0, 'maximum': 4096},
          },
        },
      },
      'required': ['edges', 'prompt'],
    },
    executeFn: (_, arguments) => expandCanvas(arguments),
  ),
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
