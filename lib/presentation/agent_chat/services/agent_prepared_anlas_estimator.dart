import 'generation_preparation_runtime.dart';
import 'manual_inpaint_toolbox.dart';
import 'queue_toolbox.dart';

/// 计费估算只认已登记的 preparation：缺少 preparation id 的调用还没进入计费阶段。
Future<int?> estimatePreparedAnlas(
  String toolName,
  Map<String, dynamic> args, {
  required GenerationPreparationRuntime generationRuntime,
  required QueueControlRuntime queueRuntime,
  required ManualInpaintToolbox manualInpaintToolbox,
}) async {
  if (toolName == 'submit_generation' ||
      toolName == 'generate_image' ||
      toolName == 'queue_image_task') {
    final id = args['preparation_id'];
    if (id is String) {
      return generationRuntime.get(id)?.estimatedAnlas;
    }
  }
  if (toolName == 'submit_manual_inpaint_draft') {
    final id = args['draft_id'];
    return id is String
        ? await manualInpaintToolbox.estimateAnlasForDraft(id)
        : null;
  }
  if (toolName == 'start_generation_queue' ||
      toolName == 'resume_generation_queue') {
    final id = args['queue_preparation_id'];
    return id is String ? queueRuntime.get(id)?.estimatedAnlas : null;
  }
  return null;
}
