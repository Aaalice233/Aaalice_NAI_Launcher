import 'dart:convert';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/inpaint_mask/inpaint_mask_geometry.dart';
import '../../../core/utils/inpaint_mask/inpaint_mask_operations.dart';
import '../../../core/utils/inpaint_mask/inpaint_mask_preview.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../../../data/models/inpaint/inpaint_draft_status.dart';
import '../../../data/services/inpaint_draft_repository.dart';
import '../../providers/generation/generation_request_preparation_service.dart';
import 'agent_image_observation_ledger.dart';
import 'defined_agent_tool.dart';
import 'inpaint_mask_authoring.dart';
import 'manual_inpaint_toolbox_serialization.dart';

/// [filePath] 只用于观察台账比对，不进入模型可见输出。
typedef InpaintResolvedSource = ({Uint8List bytes, String? filePath});

class InpaintSourceResolution {
  const InpaintSourceResolution.ok(this.resource) : error = null;
  const InpaintSourceResolution.failed(this.error) : resource = null;

  final InpaintResolvedSource? resource;
  final AgentToolResult? error;
}

/// 机器生成蒙版所需的共享草稿设施，由 ManualInpaintToolbox 提供。
abstract interface class InpaintDraftAuthoringHost {
  InpaintDraftRepository get draftRepository;
  String? get currentSessionId;
  int get requestBatchSize;
  ImageParams get baseGenerationParams;

  Future<InpaintSourceResolution> resolveInpaintSource(
    Map<String, dynamic> args,
  );

  int estimateInfillAnlas(
    ImageParams params, {
    required int batchSize,
    required Uint8List? maskImage,
    required GenerationFocusedSnapshot focused,
  });

  GenerationFocusedSnapshot readFocusedSnapshot(Map<String, dynamic> snapshot);

  void bindDraftSession(String draftId, String sessionId);

  Future<void> notifyDraftChanged(InpaintDraft draft);
}

/// Builds inpaint drafts whose mask comes from geometry or canvas expansion
/// instead of the editor.
class InpaintDraftAuthoringService {
  InpaintDraftAuthoringService(this._host);

  final InpaintDraftAuthoringHost _host;
  AgentImageObservationLedger? _observationLedger;
  String Function()? _observationSessionId;

  void configureObservationLedger(
    AgentImageObservationLedger ledger, {
    required String Function() activeSessionId,
  }) {
    _observationLedger = ledger;
    _observationSessionId = activeSessionId;
  }

  Future<AgentToolResult> createFromGeometry(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return agentToolError('invalid_prompt', 'prompt must not be empty.');
    }
    final InpaintMaskAuthoringRequest request;
    try {
      request = InpaintMaskAuthoring.parse(args);
    } on InpaintMaskAuthoringException catch (error) {
      return agentToolError(error.code, error.message);
    }

    final resolution = await _host.resolveInpaintSource(args);
    final resolutionError = resolution.error;
    if (resolutionError != null) return resolutionError;
    final resource = resolution.resource!;
    final notObserved = _requireObservedSource(resource.filePath);
    if (notObserved != null) return notObserved;

    final size = NaiResolutionAdapter.readImageSize(resource.bytes);
    if (size == null) {
      return agentToolError(
        'invalid_source',
        'The source image could not be decoded.',
      );
    }
    final (width, height) = size;

    final Uint8List maskBinary;
    try {
      maskBinary = InpaintMaskGeometry.rasterizeBinary(
        regions: request.regions,
        width: width,
        height: height,
        expandRatio: request.expandRatio,
      );
    } on InpaintMaskGeometryException catch (error) {
      return agentToolError('invalid_regions', error.message);
    }

    final maskedPixels = maskBinary.fold<int>(0, (total, v) => total + v);
    if (maskedPixels == 0) {
      return agentToolError(
        'empty_mask',
        'The regions produced an empty mask. Widen them or raise expand_ratio.',
      );
    }

    final focusedEnabled = InpaintMaskAuthoring.resolveFocusedEnabled(
      preference: request.focus,
      maskedPixels: maskedPixels,
      imagePixels: width * height,
    );

    return _commit(
      source: resource.bytes,
      maskBinary: maskBinary,
      width: width,
      height: height,
      prompt: prompt,
      paramOverrides: args['params'],
      encodedReference: args['source_ref'],
      focusedEnabled: focusedEnabled,
      contextPadding: request.contextPadding,
      includePreview: args['preview'] != false,
    );
  }

  Future<AgentToolResult> createFromExpansion(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return agentToolError('invalid_prompt', 'prompt must not be empty.');
    }
    final rawEdges = args['edges'];
    if (rawEdges is! Map) {
      return agentToolError(
        'invalid_edges',
        'edges must be an object with left, top, right and bottom pixels.',
      );
    }
    final edges = Map<String, dynamic>.from(rawEdges);
    int edge(String name) {
      final value = edges[name];
      if (value == null) return 0;
      final pixels = value is num ? value.toInt() : -1;
      if (pixels < 0 || pixels > 4096) {
        throw const FormatException(
          'edges values must be integers from 0 to 4096 pixels.',
        );
      }
      return pixels;
    }

    final OutpaintEdges expansion;
    try {
      expansion = OutpaintEdges(
        left: edge('left'),
        top: edge('top'),
        right: edge('right'),
        bottom: edge('bottom'),
      );
    } on FormatException catch (error) {
      return agentToolError('invalid_edges', error.message);
    }
    if (expansion.isEmpty) {
      return agentToolError(
        'invalid_edges',
        'At least one edge must be greater than zero.',
      );
    }

    // 扩图只用四个边距、不依赖视觉定位，因此不做观察台账校验。
    final resolution = await _host.resolveInpaintSource(args);
    final resolutionError = resolution.error;
    if (resolutionError != null) return resolutionError;
    final resource = resolution.resource!;

    final OutpaintExpansionResult expanded;
    try {
      expanded = await InpaintOutpaintUtils.expandAsync(
        sourceImage: resource.bytes,
        edges: expansion,
      );
    } on Object catch (error) {
      return agentToolError('expand_failed', '$error');
    }

    final decodedMask = InpaintMaskUtils.decodeBinaryMask(expanded.maskImage);
    if (decodedMask == null) {
      return agentToolError(
        'expand_failed',
        'The generated outpaint mask could not be decoded.',
      );
    }

    return _commit(
      source: expanded.sourceImage,
      maskBinary: decodedMask.mask,
      width: decodedMask.width,
      height: decodedMask.height,
      prompt: prompt,
      paramOverrides: args['params'],
      encodedReference: null,
      // 新增画布本身就是整块空白，裁剪到局部反而丢掉衔接所需的上下文。
      focusedEnabled: false,
      contextPadding: null,
      includePreview: args['preview'] != false,
      sourceIsOutpaint: true,
      extraDetails: {
        'appliedEdges': {
          'left': expanded.appliedEdges.left,
          'top': expanded.appliedEdges.top,
          'right': expanded.appliedEdges.right,
          'bottom': expanded.appliedEdges.bottom,
        },
        'size': '${expanded.width}x${expanded.height}',
      },
    );
  }

  Future<AgentToolResult> _commit({
    required Uint8List source,
    required Uint8List maskBinary,
    required int width,
    required int height,
    required String prompt,
    required Object? paramOverrides,
    required Object? encodedReference,
    required bool focusedEnabled,
    required int? contextPadding,
    required bool includePreview,
    bool sourceIsOutpaint = false,
    Map<String, dynamic> extraDetails = const {},
  }) async {
    final repository = _host.draftRepository;
    final sessionId = _host.currentSessionId;
    bool isCurrentSession() => _host.currentSessionId == sessionId;
    String? createdDraftId;
    try {
      final maskPng = InpaintMaskUtils.encodeBinaryMask(
        maskBinary,
        width,
        height,
      );
      final snapshot = buildManualInpaintParameterSnapshot(
        _host.baseGenerationParams,
        prompt,
        paramOverrides,
        sourceImage: source,
      );
      if (encodedReference != null) {
        snapshot['_agentSourceReference'] =
            AgentChatResourceReferenceCodec.encodeJsonMap(
              AgentChatResourceReferenceCodec.decodeJsonMap(
                Map<String, dynamic>.from(encodedReference as Map),
              ),
            );
      }
      snapshot['_agentFocusedInpaint'] = {
        'enabled': focusedEnabled,
        if (contextPadding != null) 'contextPadding': contextPadding,
      };
      snapshot['_agentSourceIsOutpaint'] = sourceIsOutpaint;
      final batchSize = _host.requestBatchSize;
      snapshot['_agentBatchSize'] = batchSize;
      final estimatedAnlas = _host.estimateInfillAnlas(
        ImageParams.fromJson(snapshot),
        batchSize: batchSize,
        maskImage: maskPng,
        focused: _host.readFocusedSnapshot(snapshot),
      );
      final prepared = await repository.prepare(
        sourceBytes: source,
        parameterSnapshot: snapshot,
        estimatedAnlas: estimatedAnlas,
      );
      createdDraftId = prepared.id;
      if (!isCurrentSession()) {
        await repository.cancel(prepared.id);
        return agentToolError(
          'session_switched',
          'The Agent session changed before the inpaint draft was stored.',
        );
      }
      _host.bindDraftSession(prepared.id, sessionId ?? '');
      final editing = await repository.beginEditing(prepared.id);
      final ready = await repository.complete(
        editing.id,
        sourceBytes: source,
        maskBytes: maskPng,
        parameterSnapshot: snapshot,
        estimatedAnlas: editing.estimatedAnlas,
      );
      await _host.notifyDraftChanged(ready);

      final details = <String, dynamic>{
        'ok': true,
        'draft': manualInpaintDraftJson(ready),
        'maskCoverage': double.parse(
          (maskBinary.fold<int>(0, (total, v) => total + v) / (width * height))
              .toStringAsFixed(4),
        ),
        'focusedInpaint': focusedEnabled,
        ...extraDetails,
      };
      final content = <ToolResultContent>[
        ToolResultTextContent(jsonEncode(details)),
      ];
      if (includePreview) {
        final overlay = await _buildMaskPreview(
          source: source,
          maskBinary: maskBinary,
          width: width,
          height: height,
        );
        if (overlay != null) content.add(overlay);
      }
      return AgentToolResult(content: content, details: details);
    } on Object catch (error) {
      if (createdDraftId != null) {
        final current = await repository.get(createdDraftId);
        if (current != null &&
            (current.status == InpaintDraftStatus.prepared ||
                current.status == InpaintDraftStatus.editing)) {
          await repository.cancel(createdDraftId);
        }
      }
      return agentToolError('create_failed', '$error');
    }
  }

  Future<ToolResultContent?> _buildMaskPreview({
    required Uint8List source,
    required Uint8List maskBinary,
    required int width,
    required int height,
  }) async {
    try {
      final preview = await InpaintMaskPreview.renderAsync(
        sourceImage: source,
        maskBinary: maskBinary,
        width: width,
        height: height,
      );
      if (preview == null) return null;
      final mimeType = detectSupportedImageMimeType(preview);
      if (mimeType == null) return null;
      return ToolResultImageContent(
        ImageContent(
          source: ImageSource.base64(
            mimeType: mimeType,
            base64Data: base64Encode(preview),
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Inpaint mask preview rendering failed',
        error,
        stackTrace,
        'AgentChat',
      );
      return null;
    }
  }

  /// 没有台账记录说明模型没真正看过这张图，坐标只能是猜的，不能放行到扣费环节。
  AgentToolResult? _requireObservedSource(String? filePath) {
    final ledger = _observationLedger;
    final sessionId = _observationSessionId?.call();
    if (ledger == null || sessionId == null) return null;
    if (filePath != null && ledger.hasObserved(sessionId, filePath)) {
      return null;
    }
    return agentToolError(
      'image_not_observed',
      'Read the source image with the read tool before authoring a mask for '
          'it, so the coordinates come from the image instead of a guess. '
          'Generated images expose a workspace path only when they are saved '
          'to disk.',
    );
  }
}
