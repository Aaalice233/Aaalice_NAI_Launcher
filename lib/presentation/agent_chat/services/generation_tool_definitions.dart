import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../providers/replication_queue_provider.dart';
import 'defined_agent_tool.dart';
import 'generation_history_service.dart';
import 'generation_interrogation_service.dart';
import 'generation_preparation_service.dart';
import 'generation_preparation_schema.dart';
import 'generation_settings_service.dart';
import 'generation_status_service.dart';
import 'generation_tool_results.dart';
import 'generation_tool_limits.dart';

class GenerationToolDefinitions {
  GenerationToolDefinitions({
    required GenerationInterrogationService interrogation,
    required GenerationPreparationService preparation,
    required GenerationStatusService status,
    required GenerationSettingsService settings,
    required GenerationHistoryService history,
  }) : _interrogation = interrogation,
       _preparation = preparation,
       _status = status,
       _settings = settings,
       _history = history;

  final GenerationInterrogationService _interrogation;
  final GenerationPreparationService _preparation;
  final GenerationStatusService _status;
  final GenerationSettingsService _settings;
  final GenerationHistoryService _history;

  List<AgentTool> tools() {
    return [
      DefinedAgentTool(
        name: 'interrogate_image',
        label: 'Interrogate Image',
        description:
            'Reverse-engineer a NovelAI prompt from an image. '
            'Returns English comma-separated tags. Routing: uses the '
            'current chat model directly when it supports image input; '
            'the dedicated "reverse" vision model (Settings > '
            'Integrations) is only a fallback and is NOT required. '
            'Provide exactly one source: attachment_index for an inline image '
            'in the latest user message (1-based in message order), '
            'resource_ref for an application image, or path for an existing '
            'local image file. Inline attachments have no file path; never '
            'invent a path for them.',
        parameters: const {
          'type': 'object',
          'properties': {
            'attachment_index': {
              'type': 'integer',
              'minimum': 1,
              'description': '1-based image index in the latest user message.',
            },
            'resource_ref': AgentChatResourceReferenceCodec.jsonSchema,
            'path': {
              'type': 'string',
              'description':
                  'Image file path (workspace-relative or absolute).',
            },
          },
          'required': <String>[],
          'additionalProperties': false,
        },
        executeWithControl: _interrogation.interrogate,
      ),
      DefinedAgentTool(
        name: 'prepare_generation',
        label: 'Prepare Generation',
        description:
            'Prepare an image generation transaction without submitting it. '
            'Returns a persistent preparation_id and the exact estimated '
            'Anlas cost. operation is generate (synchronous) or queue. '
            'Submit exact zero-cost preparations directly. Paid submissions '
            'use confirmed=true and the application permission approval UI.',
        parameters: {
          'type': 'object',
          'properties': generationPreparationProperties(includeOperation: true),
          'required': const ['operation', 'prompt'],
        },
        executeFn: (_, args) => _preparation.prepare(args),
      ),
      DefinedAgentTool(
        name: 'inspect_generation_preparation',
        label: 'Inspect Generation Preparation',
        description:
            'Inspect a prepared generation transaction and its Anlas estimate.',
        parameters: const {
          'type': 'object',
          'properties': {
            'preparation_id': {'type': 'string'},
          },
          'required': ['preparation_id'],
        },
        executeFn: (_, args) => _preparation.inspectPreparation(args),
      ),
      DefinedAgentTool(
        name: 'update_generation_preparation',
        label: 'Update Generation Preparation',
        description:
            'Replace provided fields on a prepared transaction and return a '
            'new preparation_id with a recalculated Anlas estimate. The old '
            'transaction is cancelled.',
        parameters: {
          'type': 'object',
          'properties': {
            'preparation_id': const {'type': 'string'},
            ...generationPreparationProperties(includeOperation: false),
          },
          'required': const ['preparation_id'],
        },
        executeFn: (_, args) => _preparation.updatePreparation(args),
      ),
      DefinedAgentTool(
        name: 'cancel_generation_preparation',
        label: 'Cancel Generation Preparation',
        description: 'Cancel a prepared generation transaction.',
        parameters: const {
          'type': 'object',
          'properties': {
            'preparation_id': {'type': 'string'},
          },
          'required': ['preparation_id'],
        },
        executeFn: (_, args) => _preparation.cancelPreparation(args),
      ),
      DefinedAgentTool(
        name: 'submit_generation',
        label: 'Submit Generation',
        description:
            'Submit a previously prepared transaction. Exact zero-cost '
            'preparations need no confirmation flag. Paid preparations require '
            'confirmed=true; the application then obtains permission through '
            'its approval UI. Do not ask for duplicate confirmation in chat.',
        parameters: const {
          'type': 'object',
          'properties': {
            'preparation_id': {'type': 'string'},
            'confirmed': {'type': 'boolean', 'const': true},
          },
          'required': ['preparation_id'],
        },
        executeWithControl: _preparation.submitPreparation,
      ),
      DefinedAgentTool(
        name: 'generate_image',
        label: 'Generate Image',
        description:
            'SYNCHRONOUS image generation (the default): waits for the '
            'images to finish and shows them as thumbnails in the chat. '
            'Uses the current generation page settings, overriding prompt '
            '/ negative_prompt / width / height / count / seed. '
            'Important: "count" generates N variations of the SAME prompt '
            '(e.g. count=3 -> three versions of one prompt). For several '
            'DIFFERENT prompts, call this tool once per prompt instead. '
            '"prompt" is required; write English danbooru-style tags. '
            '(2) "count" = how many variations of the SAME prompt; minimum '
            '1, maximum $generationToolMaxGenerateCount. It maps 1:1 to the app '
            '"generation count" setting and runs on the app-native batch '
            'pipeline as sequential requests (429 concurrency limits are '
            'retried automatically). Total images = count x the "images '
            'per request" app setting (default 1, so count usually equals '
            'total). '
            '(3) "width"/"height": prefer NAI presets — Normal portrait '
            '832x1216, landscape 1216x832, square 1024x1024; Large '
            '1024x1536 / 1536x1024 / 1472x1472; Wallpaper 1088x1920 / '
            '1920x1088; Small 512x768 / 768x512 / 640x640. Custom sizes '
            'are allowed but limited: width and height MUST be multiples '
            'of 64 (minimum 64), each side at most 4096, total pixels at '
            'most 3145728. Omit to reuse the generation '
            'page size. '
            '(4) "seed": omit or -1 for random. A fixed seed is honored '
            'only when count = 1; with count > 1 every image gets an '
            'independent random seed (identical to the generation page). '
            '(5) img2img/inpaint: provide "source_image" (local file path) '
            'to base the generation on an existing image; "strength" '
            '(0-0.99) controls how different the result may be; add '
            '"mask_image" (same size as source, white = redrawn area) to '
            'switch to inpaint with "inpaint_strength" (0-0.99); "noise" '
            '(0-0.99) adds variation. Without "source_image" this is plain '
            'text-to-image regardless of the generation page img2img '
            'state. These arguments apply to this single transaction only and '
            'never change the generation page Image2Image panel; use '
            'set_generation_source_image when the user should see the image '
            'loaded there. '
            'If a generation is already running, this waits up to 300s and '
            'runs in order. Each saved image returns path as the exact '
            'workspace-relative argument for read plus an application-owned '
            'resource_ref; never derive one from the other. Thumbnails appear '
            'in the chat. For normal "draw/generate" requests '
            'always use this tool instead of queue_image_task.',
        parameters: const {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Positive prompt; English danbooru-style tags.',
            },
            'negative_prompt': {
              'type': 'string',
              'description':
                  'Omit to reuse the generation page negative '
                  'prompt.',
            },
            'width': {
              'type': 'integer',
              'minimum': 64,
              'maximum': NaiResolutionAdapter.generationMaxSide,
              'description':
                  'Width in px; must be a multiple of 64. Prefer preset '
                  'values (512/640/768/832/1024/1088/1216/1472/1536/1920).',
            },
            'height': {
              'type': 'integer',
              'minimum': 64,
              'maximum': NaiResolutionAdapter.generationMaxSide,
              'description':
                  'Height in px; must be a multiple of 64. Prefer preset '
                  'values (768/640/512/1216/1024/832/1536/1472/1920/1088).',
            },
            'count': {
              'type': 'integer',
              'minimum': 1,
              'maximum': generationToolMaxGenerateCount,
              'description':
                  'How many variations of the SAME prompt to generate '
                  '(max $generationToolMaxGenerateCount). Default 1. For DIFFERENT '
                  'prompts, call the tool once per prompt.',
            },
            'seed': {
              'type': 'integer',
              'minimum': -1,
              'description':
                  'Omit or -1 for random. A fixed seed only '
                  'applies when count = 1.',
            },
            'source_image': {
              'type': 'string',
              'description':
                  'Local image file path to use as img2img base for this '
                  'call only; the generation page panel is left unchanged.',
            },
            'mask_image': {
              'type': 'string',
              'description':
                  'Local mask file path (white = redraw area, '
                  'same size as source) to switch to inpaint.',
            },
            'strength': {
              'type': 'number',
              'minimum': 0,
              'maximum': 0.99,
              'description':
                  'img2img strength 0-0.99. Higher = further from '
                  'the source image.',
            },
            'noise': {
              'type': 'number',
              'minimum': 0,
              'maximum': 0.99,
              'description': 'Extra img2img noise 0-0.99.',
            },
            'inpaint_strength': {
              'type': 'number',
              'minimum': 0,
              'maximum': 0.99,
              'description':
                  'Inpaint strength 0-0.99 (only with '
                  'mask_image).',
            },
            'preparation_id': {
              'type': 'string',
              'description': 'ID returned by the first unconfirmed call.',
            },
            'confirmed': {
              'type': 'boolean',
              'description':
                  'Required only for paid preparations; exact zero-cost submissions omit this.',
            },
          },
          'required': ['prompt'],
        },
        executeWithControl: _preparation.generateLegacy,
      ),
      DefinedAgentTool(
        name: 'queue_image_task',
        label: 'Queue Image Task',
        description:
            'ASYNCHRONOUS queueing: enqueues N IDENTICAL tasks (same '
            'prompt) into the generation queue and returns immediately '
            'WITHOUT producing images in the chat. "count" only creates '
            'N copies of the SAME prompt; for DIFFERENT prompts call this '
            'tool once per prompt (or use generate_image for synchronous '
            'results). ONLY use this when the user explicitly asks to '
            'add tasks to a queue / background batch; for normal image '
            'requests use generate_image instead. Requirements: "prompt" '
            'is required; "count" 1-50, capped by the queue\'s remaining '
            'capacity (tool reports an error when full); "auto_start" '
            'starts the queue after adding (default true). Queue outputs '
            'do NOT appear automatically; get_recent_images can retrieve '
            'them later.',
        parameters: const {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Positive prompt; English danbooru-style tags.',
            },
            'negative_prompt': {
              'type': 'string',
              'description':
                  'Omit to reuse the generation page negative '
                  'prompt.',
            },
            'count': {
              'type': 'integer',
              'minimum': 1,
              'maximum': kMaxQueueCapacity,
              'description':
                  'How many identical tasks to enqueue. Default 1. '
                  'Maximum 50 and capped by remaining queue capacity.',
            },
            'auto_start': {
              'type': 'boolean',
              'description': 'Start the queue after adding. Default true.',
            },
            'preparation_id': {
              'type': 'string',
              'description': 'ID returned by the first unconfirmed call.',
            },
            'confirmed': {
              'type': 'boolean',
              'description':
                  'Required only for paid preparations; exact zero-cost submissions omit this.',
            },
          },
          'required': ['prompt'],
        },
        executeWithControl: _preparation.queueLegacy,
      ),
      DefinedAgentTool(
        name: 'get_generation_status',
        label: 'Get Generation Status',
        description:
            'Report current generation progress, queue statistics, '
            'and stable references for recently generated images.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async => generationTextResult(_status.statusJson()),
      ),
      DefinedAgentTool(
        name: 'get_recent_images',
        label: 'Get Recent Images',
        description:
            'Return the newest saved generation-history images (including '
            'queue outputs) using the same contract as generate_image: path '
            'is the exact workspace-relative argument for read and '
            'resource_ref is the application-owned identity for resource '
            'tools. Never derive one from the other. "limit" is required on '
            'every call. When the user '
            'requests a specific number, pass that exact number.',
        parameters: const {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': generationToolMaxRecentImageLimit,
              'description':
                  'Required number of newest images to return. Use the exact '
                  'number requested by the user; maximum '
                  '$generationToolMaxRecentImageLimit.',
            },
          },
          'required': ['limit'],
        },
        executeFn: (_, params) => _history.recentImages(params),
      ),
      DefinedAgentTool(
        name: 'get_generation_settings',
        label: 'Get Generation Settings',
        description:
            'Read all image generation settings: model, sampler, '
            'steps, scale (CFG), cfg_rescale, noise_schedule, uc_preset, '
            'quality_toggle, variety_plus, decrisp, smea flags, '
            'transparent_background, width/height, seed, generation count, '
            'action (generate/img2img/infill) and strength values. Call '
            'this before update_generation_settings to learn current values '
            'and valid model ids.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async =>
            generationTextResult(_settings.settingsJson()),
      ),
      DefinedAgentTool(
        name: 'update_generation_settings',
        label: 'Update Generation Settings',
        description:
            'Persistently change generation page settings. Only '
            'provided fields are changed. Requirements: "model" accepts an '
            'exact model id OR a friendly name like "v5", "v5 curated", '
            '"v4.5 full", "v3" (get_generation_settings lists all); '
            'switching model may auto-adjust scale/steps defaults. '
            '"sampler" examples: k_euler_ancestral, k_euler, k_dpmpp_2m, '
            'k_dpmpp_2m_sde. "steps" clamped to 1-50; "scale" 0-10; '
            '"cfg_rescale" 0-1; "noise_schedule" one of '
            'native/karras/exponential/polyexponential (V4+ models, '
            '"light" on V5); "uc_preset" integer preset index; "seed" -1 '
            'for random; the rest are booleans. "transparent_background" '
            'is the transparency switch — enable it when the user asks '
            'for a transparent background (V5 renders native alpha; '
            'optionally reinforce with the prompt tags). Changes apply to '
            'the generation page UI immediately and persist across '
            'restarts.',
        parameters: const {
          'type': 'object',
          'properties': {
            'model': {'type': 'string'},
            'sampler': {'type': 'string', 'enum': Samplers.allSamplers},
            'steps': {'type': 'integer', 'minimum': 1, 'maximum': 50},
            'scale': {'type': 'number', 'minimum': 0, 'maximum': 10},
            'cfg_rescale': {'type': 'number', 'minimum': 0, 'maximum': 1},
            'noise_schedule': {'type': 'string', 'enum': NoiseSchedules.all},
            'uc_preset': {
              'type': 'integer',
              'enum': [
                UcPresets.heavyApiValue,
                UcPresets.lightApiValue,
                UcPresets.humanFocusApiValue,
                UcPresets.noneApiValue,
                UCPresets.furryFocus,
              ],
            },
            'quality_toggle': {'type': 'boolean'},
            'variety_plus': {'type': 'boolean'},
            'decrisp': {'type': 'boolean'},
            'transparent_background': {'type': 'boolean'},
            'smea': {'type': 'boolean'},
            'smea_dyn': {'type': 'boolean'},
            'seed': {
              'type': 'integer',
              'minimum': -1,
              'description': '-1 for random.',
            },
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _settings.updateSettings(params),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // interrogate_image
  // -------------------------------------------------------------------------
}
