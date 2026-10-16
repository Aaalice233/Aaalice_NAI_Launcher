import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../providers/generation/image_workflow_controller.dart';
import 'agent_image_source_loader.dart';
import 'defined_agent_tool.dart';
import 'generation_image_read_contract.dart';
import 'generation_save_path_exporter.dart';
import 'generation_save_path_validator.dart';
import 'image_upscale_service.dart';

/// 跨注册表重建存活，审批阶段的报价在权限模式切换后仍归执行使用。
final class ImageUpscaleToolbox {
  ImageUpscaleToolbox(this._ref);

  final Ref _ref;
  ImageUpscaleService? _service;

  /// 工具串行执行，同一时刻最多一笔待执行的报价。
  ImageUpscaleQuote? _quote;

  /// 文件作用域随权限模式变化，每次构建注册表时重新配置。
  void configure({
    required AgentImageSourceLoader sourceLoader,
    required GenerationSavePathValidator savePathValidator,
    required GenerationSavePathExporter exporter,
    required GenerationImageReadContract readContract,
    required bool referencesGalleryOriginal,
  }) {
    _service = ImageUpscaleService(
      _ref,
      sourceLoader: sourceLoader,
      savePathValidator: savePathValidator,
      exporter: exporter,
      readContract: readContract,
      referencesGalleryOriginal: referencesGalleryOriginal,
    );
  }

  ImageUpscaleService get _configured {
    final service = _service;
    if (service == null) {
      throw StateError('ImageUpscaleToolbox used before configure().');
    }
    return service;
  }

  /// 审批前估价。参数或原图本身不成立时这次调用不会发出请求，记为 0；
  /// 原图超出计费分档返回 `AnlasCalculator.invalidCost`，由审批直接拦下。
  Future<int?> estimateAnlas(Map<String, dynamic> args) async {
    _quote = null;
    _quote = await _configured.quote(args);
    return _quote?.cost ?? 0;
  }

  Future<AgentToolResult> _upscale(
    String toolCallId,
    Map<String, dynamic> args,
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ) {
    final quote = _quote;
    _quote = null;
    return _configured.upscale(toolCallId, args, quote, signal, onUpdate);
  }

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'upscale_image',
      label: 'Upscale Image',
      description:
          'Upscale one image and add the result to generation history, like '
          'the generation page Upscale panel. Provide exactly one of '
          'resource_ref (any generated, gallery, Vibe, precise-reference or '
          'inpaint-draft image) or image_path. backend novelai is the cloud '
          'upscaler: it may spend Anlas, billed by the source area (free on '
          'Opus up to 640x640), and rejects sources above 3145728 pixels. '
          'backend comfyui runs locally for free with the module and model '
          'chosen on the generation page. Omitted backend and scale follow the '
          'generation page Upscale settings and are never written back. Paid '
          'calls wait for launcher approval; do not ask again in chat. The '
          'result keeps the source image metadata and replaces the generation '
          'page display. This is a pure upscaler; use prepare_generation with '
          'enhance to re-render details.',
      parameters: {
        'type': 'object',
        'properties': {
          'resource_ref': const {'type': 'object'},
          'image_path': const {
            'type': 'string',
            'description': 'Local image file path to upscale.',
          },
          'backend': {
            'type': 'string',
            'enum': ImageUpscaleService.backendWireNames,
          },
          'scale': const {
            'type': 'number',
            'minimum': UpscaleWorkflowSettings.minScale,
            'maximum': UpscaleWorkflowSettings.maxScale,
            'description':
                'ComfyUI output scale; NovelAI has a fixed scale and rejects '
                'this argument.',
          },
          'save_path': const {
            'type': 'string',
            'description':
                'Optional .png file target for the result, workspace-relative '
                'or a permitted absolute path. {id} is available; {seed} is '
                'not, because upscaled images carry no generation seed.',
          },
        },
        'required': const <String>[],
        'additionalProperties': false,
      },
      executionModeOverride: ToolExecutionMode.sequential,
      executeWithControl: _upscale,
    ),
  ];
}
