import 'dart:convert';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
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
  Object? overrides,
) {
  final snapshot = <String, dynamic>{...base.toJson()};
  if (overrides != null) {
    if (overrides is! Map<String, dynamic>) {
      throw const FormatException('params must be an object.');
    }
    snapshot.addAll(overrides);
  }
  snapshot['prompt'] = prompt;
  snapshot['action'] = ImageGenerationAction.infill.name;
  return ImageParams.fromJson(snapshot).toJson();
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
