import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/private_data_guard.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/generation/image_workflow_controller.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_workspace_path_resolver.dart';
import 'toolbox_json.dart';

const double _maxRatio = 0.99;

/// 生成页图生图源图工具集。
///
/// 与 generate_image 的一次性 source_image 不同，这里写的是用户可见的工作区
/// 状态，走和拖拽/文件选择完全相同的 [ImageWorkflowController] 路径。
class GenerationSourceImageToolbox {
  GenerationSourceImageToolbox(
    this._ref, {
    required AgentResourceResolver resolver,
    required GenerationWorkspacePathResolver pathResolver,
  }) : _resolver = resolver,
       _pathResolver = pathResolver;

  final Ref _ref;
  final AgentResourceResolver _resolver;
  final GenerationWorkspacePathResolver _pathResolver;

  List<AgentTool> tools() => [_get(), _set(), _clear(), _updateSettings()];

  ImageWorkflowController get _workflow =>
      _ref.read(imageWorkflowControllerProvider.notifier);

  ImageWorkflowState get _workflowState =>
      _ref.read(imageWorkflowControllerProvider);

  GenerationParamsNotifier get _paramsNotifier =>
      _ref.read(generationParamsNotifierProvider.notifier);

  ImageParams get _params => _ref.read(generationParamsNotifierProvider);

  DefinedAgentTool _get() => DefinedAgentTool(
    name: 'get_generation_source_image',
    label: 'Get Generation Source Image',
    description:
        'Read the Image2Image source image state on the generation page: '
        'whether a source is loaded, its pixel size, the adapted request size, '
        'the current action and sub-mode, mask presence, and the strength / '
        'noise / inpaint_strength values. Call this before changing anything. '
        'File paths are never returned.',
    parameters: toolboxObject(),
    executeFn: (_, __) async => agentToolJsonResult(_stateJson()),
  );

  DefinedAgentTool _set() => DefinedAgentTool(
    name: 'set_generation_source_image',
    label: 'Set Generation Source Image',
    description:
        'Load one image into the Image2Image source slot on the generation '
        'page, exactly like the user dropping a file or choosing "send to '
        'Image2Image". This switches the page to img2img and expands the '
        'panel; the source persists and affects the next manual generation, '
        'so tell the user when you replace an existing source. Provide '
        'exactly one of resource_ref (any generated, gallery, Vibe, '
        'precise-reference or inpaint-draft image) or image_path (a local '
        'file; outside-workspace paths need Full Access). Loading also snaps '
        'the generation width and height to the NovelAI import resolution for '
        'that aspect ratio, reported back as request_size. An active Enhance '
        'or Upscale sub-mode is kept, but a loaded inpaint mask is dropped '
        'because it no longer matches the new image. This never spends Anlas '
        'and never starts a generation.',
    parameters: toolboxObject(
      properties: {
        'resource_ref': {'type': 'object'},
        'image_path': {
          'type': 'string',
          'description': 'Local image file path to load as the source image.',
        },
        'strength': {
          'type': 'number',
          'minimum': 0,
          'maximum': _maxRatio,
          'description': 'Higher = further from the source image.',
        },
        'noise': {'type': 'number', 'minimum': 0, 'maximum': _maxRatio},
      },
      required: const <String>[],
    ),
    // 写生成页 UI 状态，不能与同批工具并发。
    executionModeOverride: ToolExecutionMode.sequential,
    executeFn: (_, params) => _setSourceImage(params),
  );

  DefinedAgentTool _clear() => DefinedAgentTool(
    name: 'clear_generation_source_image',
    label: 'Clear Generation Source Image',
    description:
        'Remove the Image2Image source image and its mask from the generation '
        'page and return it to plain text-to-image. Safe to call when no '
        'source is loaded.',
    parameters: toolboxObject(),
    executionModeOverride: ToolExecutionMode.sequential,
    executeFn: (_, __) async {
      final had = _params.sourceImage != null;
      if (had) _workflow.clearSourceImage();
      return agentToolJsonResult({'cleared': had, ..._stateJson()});
    },
  );

  DefinedAgentTool _updateSettings() => DefinedAgentTool(
    name: 'update_generation_source_settings',
    label: 'Update Generation Source Settings',
    description:
        'Change the Image2Image strength, noise, or inpaint_strength on the '
        'generation page, identical to moving those sliders. Requires a '
        'loaded source image. The Enhance and Upscale sub-modes own strength '
        'and noise themselves, so those two are rejected while either is '
        'active.',
    parameters: toolboxObject(
      properties: {
        'strength': {'type': 'number', 'minimum': 0, 'maximum': _maxRatio},
        'noise': {'type': 'number', 'minimum': 0, 'maximum': _maxRatio},
        'inpaint_strength': {
          'type': 'number',
          'minimum': 0,
          'maximum': _maxRatio,
          'description': 'Only affects generations that carry a mask.',
        },
      },
      required: const <String>[],
    ),
    executionModeOverride: ToolExecutionMode.sequential,
    executeFn: (_, params) async {
      final ratios = _SourceRatios.parse(params);
      if (ratios.isEmpty) {
        return agentToolError(
          'no_settings',
          'Provide at least one of strength, noise, or inpaint_strength.',
        );
      }
      if (_params.sourceImage == null) {
        return agentToolError(
          'no_source_image',
          'Load an Image2Image source image before changing its settings.',
        );
      }
      final rejection = _rejectRatiosOwnedBySubMode(ratios);
      if (rejection != null) return rejection;
      _writeRatios(ratios);
      return agentToolJsonResult(_stateJson());
    },
  );

  Future<AgentToolResult> _setSourceImage(Map<String, dynamic> params) async {
    final rawPath = (params['image_path'] as String?)?.trim() ?? '';
    final hasReference = params['resource_ref'] != null;
    if (hasReference == rawPath.isNotEmpty) {
      return agentToolError(
        'invalid_source',
        'Provide exactly one of resource_ref or image_path.',
      );
    }

    // 载入不会把 enhance/upscale 切回 base，所以子模式裁决在写入前后等价；
    // 提前拒绝可以避免"图已换、参数没生效"的半成功。
    final ratios = _SourceRatios.parse(params);
    final rejection = _rejectRatiosOwnedBySubMode(ratios);
    if (rejection != null) return rejection;

    final source = hasReference
        ? await _resolveReference(params['resource_ref'])
        : await _resolveFile(rawPath);
    if (source.error != null) return source.error!;

    final bytes = source.bytes!;
    if (NaiResolutionAdapter.readImageSize(bytes) == null) {
      return agentToolError(
        'invalid_image',
        'The provided data could not be decoded as an image.',
      );
    }

    await _workflow.replaceSourceImageAsync(bytes);
    _workflow.setPanelExpanded(true);
    _writeRatios(ratios);

    return agentToolJsonResult({
      if (source.encodedReference != null)
        'resource_ref': source.encodedReference,
      ..._stateJson(),
    });
  }

  Future<_SourceImageBytes> _resolveReference(dynamic rawReference) async {
    try {
      final reference = _resolver.decode(rawReference);
      final resolved = await _resolver.resolve(reference);
      if (resolved == null) {
        return _SourceImageBytes.failed(
          'resource_unavailable',
          'The referenced resource is unavailable.',
        );
      }
      final bytes = resolved.bytes;
      if (bytes == null || bytes.isEmpty) {
        return _SourceImageBytes.failed(
          'not_an_image',
          'The referenced resource has no image data.',
        );
      }
      return _SourceImageBytes(
        bytes: bytes,
        encodedReference: AgentChatResourceReferenceCodec.encodeJsonMap(
          resolved.reference,
        ),
      );
    } on FormatException catch (error) {
      return _SourceImageBytes.failed('invalid_resource_ref', '$error');
    }
  }

  Future<_SourceImageBytes> _resolveFile(String rawPath) async {
    final String resolved;
    try {
      resolved = await _pathResolver.resolveLocalImagePath(rawPath);
    } on Object {
      return _SourceImageBytes.failed(
        'image_path_not_permitted',
        'Image path is not permitted.',
      );
    }
    final file = File(resolved);
    if (!file.existsSync()) {
      return _SourceImageBytes.failed(
        'source_not_found',
        'Source image not found.',
      );
    }
    try {
      return _SourceImageBytes(bytes: await file.readAsBytes());
    } on Object catch (error) {
      return _SourceImageBytes.failed(
        'source_unreadable',
        PrivateDataGuard.redactAbsolutePaths('$error'),
      );
    }
  }

  /// 两种子模式各自管理 strength/noise，直接写进去会被它们覆盖掉。
  AgentToolResult? _rejectRatiosOwnedBySubMode(_SourceRatios ratios) {
    if (ratios.strength == null && ratios.noise == null) return null;
    return switch (_workflowState.mode) {
      ImageWorkflowMode.enhance => agentToolError(
        'enhance_owns_strength',
        'The Enhance sub-mode derives strength and noise from its own level; '
            'leave Enhance before setting them directly.',
      ),
      ImageWorkflowMode.upscale => agentToolError(
        'upscale_owns_strength',
        'The Upscale sub-mode manages strength and noise itself; '
            'leave Upscale before setting them directly.',
      ),
      ImageWorkflowMode.base || ImageWorkflowMode.inpaint => null,
    };
  }

  void _writeRatios(_SourceRatios ratios) {
    if (ratios.strength case final double value) {
      _paramsNotifier.updateStrength(value);
    }
    if (ratios.noise case final double value) {
      _paramsNotifier.updateNoise(value);
    }
    if (ratios.inpaintStrength case final double value) {
      _paramsNotifier.updateInpaintStrength(value);
    }
  }

  Map<String, dynamic> _stateJson() {
    final params = _params;
    final workflow = _workflowState;
    final source = params.sourceImage;
    final requestWidth = workflow.sourceWidth;
    final requestHeight = workflow.sourceHeight;
    return {
      'ok': true,
      'has_source_image': source != null,
      'action': params.action.name,
      'mode': workflow.mode.name,
      'source_image': source == null
          ? null
          : {
              'width': workflow.sourceImageWidth,
              'height': workflow.sourceImageHeight,
              'byte_size': source.length,
            },
      'request_size': requestWidth == null || requestHeight == null
          ? null
          : {'width': requestWidth, 'height': requestHeight},
      'has_mask': params.maskImage != null,
      'is_outpaint': params.isOutpaint,
      'strength': params.strength,
      'noise': params.noise,
      'inpaint_strength': params.inpaintStrength,
      'panel_expanded': workflow.isPanelExpanded,
    };
  }
}

class _SourceImageBytes {
  const _SourceImageBytes({this.bytes, this.encodedReference, this.error});

  factory _SourceImageBytes.failed(String code, String message) =>
      _SourceImageBytes(error: agentToolError(code, message));

  final Uint8List? bytes;
  final Map<String, dynamic>? encodedReference;
  final AgentToolResult? error;
}

class _SourceRatios {
  const _SourceRatios({this.strength, this.noise, this.inpaintStrength});

  factory _SourceRatios.parse(Map<String, dynamic> params) => _SourceRatios(
    strength: _ratio(params['strength']),
    noise: _ratio(params['noise']),
    inpaintStrength: _ratio(params['inpaint_strength']),
  );

  final double? strength;
  final double? noise;
  final double? inpaintStrength;

  bool get isEmpty =>
      strength == null && noise == null && inpaintStrength == null;

  static double? _ratio(dynamic value) =>
      (value as num?)?.toDouble().clamp(0.0, _maxRatio);
}
