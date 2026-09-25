import 'dart:convert';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../../../data/services/inpaint_draft_repository.dart';

const manualInpaintDraftIdSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'draft_id': {'type': 'string'},
  },
  'required': ['draft_id'],
};

Map<String, dynamic> manualInpaintDraftJson(InpaintDraft draft) => {
  'draftId': draft.id,
  'status': draft.status.name,
  'prompt': draft.parameterSnapshot['prompt'],
  'params': draft.parameterSnapshot,
  if (draft.parameterSnapshot['_agentSourceReference'] case final Map value)
    'sourceReference': value,
  'source': draft.source.toJson(),
  if (draft.mask != null) 'mask': draft.mask!.toJson(),
  'estimatedAnlas': draft.estimatedAnlas,
  'createdAt': draft.createdAt.toIso8601String(),
  'updatedAt': draft.updatedAt.toIso8601String(),
  if (draft.failureMessage != null) 'failure': draft.failureMessage,
};

Map<String, dynamic> buildManualInpaintParameterSnapshot(
  ImageParams base,
  String prompt,
  Object? overrides, {
  Uint8List? sourceImage,
}) {
  final snapshot = <String, dynamic>{...base.toJson()};
  if (overrides != null) {
    if (overrides is! Map<String, dynamic>) {
      throw const FormatException('params must be an object.');
    }
    snapshot.addAll(overrides);
  }
  snapshot['prompt'] = prompt;
  snapshot['action'] = ImageGenerationAction.infill.name;
  if (sourceImage != null) {
    // 请求尺寸必须跟随底图：normalizeImageForRequest 是无视宽高比的直接重采样，
    // 沿用生成页尺寸会把底图拉伸变形。
    final size = _importRequestSize(
      sourceImage,
      model: snapshot['model']?.toString() ?? base.model,
      currentWidth: (snapshot['width'] as num?)?.toInt(),
      currentHeight: (snapshot['height'] as num?)?.toInt(),
    );
    if (size != null) {
      snapshot['width'] = size.width;
      snapshot['height'] = size.height;
    }
  }
  return ImageParams.fromJson(snapshot).toJson();
}

/// 编辑器可能扩了画布或压缩了底图：请求尺寸、扩图标记和聚焦开关按生成页
/// applyInpaintEditorResult 的规则跟随新底图，其余快照字段原样保留。
Map<String, dynamic> applyManualInpaintEditorSource(
  Map<String, dynamic> snapshot,
  Uint8List sourceImage, {
  required bool isOutpaint,
  required bool compressionApplied,
}) {
  final params = ImageParams.fromJson(snapshot);
  final size = compressionApplied
      ? _exactRequestSize(sourceImage)
      : _importRequestSize(
          sourceImage,
          model: params.model,
          currentWidth: params.width,
          currentHeight: params.height,
        );
  if (size == null) {
    throw const FormatException(
      'The edited source image could not be decoded.',
    );
  }
  final updated = <String, dynamic>{
    ...snapshot,
    'width': size.width,
    'height': size.height,
    '_agentSourceIsOutpaint': isOutpaint,
  };
  // 扩出的画布整块空白，聚焦裁剪会丢掉衔接所需的上下文。
  if (updated['_agentFocusedInpaint'] case final Map focused when isOutpaint) {
    updated['_agentFocusedInpaint'] = {
      ...Map<String, dynamic>.from(focused),
      'enabled': false,
    };
  }
  return updated;
}

/// 生成页只接受 64 对齐的扩图底图，面板装载与聊天提交按同一条件认定扩图。
bool manualInpaintSourceIsOutpaint(
  Map<String, dynamic> snapshot, {
  required int width,
  required int height,
}) =>
    snapshot['_agentSourceIsOutpaint'] == true &&
    NaiResolutionAdapter.isCompatible(width, height);

({int width, int height})? _importRequestSize(
  Uint8List sourceImage, {
  required String model,
  required int? currentWidth,
  required int? currentHeight,
}) {
  final imported = NaiResolutionAdapter.describeImageForImport(
    sourceImage,
    currentWidth: currentWidth,
    currentHeight: currentHeight,
    isStableDiffusionFamily: ImageModels.usesStableDiffusionImportBounds(model),
  );
  return imported == null
      ? null
      : (width: imported.width, height: imported.height);
}

// 压缩档位就是用户选定的发送尺寸，导入推导会在宽高比相同时沿用更大的旧尺寸。
({int width, int height})? _exactRequestSize(Uint8List sourceImage) {
  final size = NaiResolutionAdapter.readImageSize(sourceImage);
  if (size == null) return null;
  final closest = NaiResolutionAdapter.findClosestResolution(size.$1, size.$2);
  return (width: closest.width, height: closest.height);
}

Future<AgentToolResult> buildManualInpaintDraftResult(
  InpaintDraft draft,
  InpaintDraftRepository repository,
) async {
  final details = <String, dynamic>{
    'ok': true,
    'draft': manualInpaintDraftJson(draft),
  };
  final content = <ToolResultContent>[
    ToolResultTextContent(jsonEncode(details)),
  ];
  final previews = <Uint8List>[await repository.readSource(draft.id)];
  if (draft.mask != null) {
    final mask = await repository.readMask(draft.id);
    if (mask != null) previews.add(mask);
  }
  for (final bytes in previews) {
    final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
    if (thumbnail == null) continue;
    final mimeType = detectSupportedImageMimeType(thumbnail);
    if (mimeType == null) continue;
    content.add(
      ToolResultImageContent(
        ImageContent(
          source: ImageSource.base64(
            mimeType: mimeType,
            base64Data: base64Encode(thumbnail),
          ),
        ),
      ),
    );
  }
  return AgentToolResult(content: content, details: details);
}
