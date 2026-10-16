import '../../core/utils/focused_inpaint_utils.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/replication_task_generation_snapshot.dart';
import 'generation/generation_request_preparation_service.dart';

/// 队列任务实际提交的生成参数，执行与估价共用同一份推导。
///
/// [snapshotParams] 为已解码的任务快照；旧任务没有快照时以生成页参数 [base] 为底。
ImageParams resolveQueuedTaskParams(
  ReplicationTask task, {
  required ImageParams base,
  ImageParams? snapshotParams,
}) {
  final negativePrompt = task.applyNegativePrompt
      ? task.negativePrompt
      : base.negativePrompt;
  if (snapshotParams != null) {
    return snapshotParams.copyWith(
      prompt: task.prompt,
      negativePrompt: negativePrompt,
      nSamples: 1,
    );
  }
  return base.copyWith(
    prompt: task.prompt,
    negativePrompt: negativePrompt,
    model: task.model ?? base.model,
    sampler: task.sampler ?? base.sampler,
    steps: task.steps ?? base.steps,
    scale: task.cfgScale ?? base.scale,
    seed: task.seed ?? -1,
    width: task.width ?? base.width,
    height: task.height ?? base.height,
    nSamples: 1,
  );
}

/// 旧快照没有聚焦段时为 null，执行端随之沿用生成页当时的聚焦状态。
GenerationFocusedSnapshot? queuedFocusedOverride(
  QueuedFocusedInpaint? focused,
) => focused == null
    ? null
    : GenerationFocusedSnapshot(
        enabled: focused.enabled,
        minimumContextMegaPixels: focused.contextPadding,
        selectionRect: focused.selectionRect,
        contextCrop: focused.contextCrop,
      );

/// 按执行端的聚焦重绘规则得到计费尺寸。
///
/// 外扩裁切区无效时执行会直接失败、不产生扣费，这里仍按原尺寸计价，宁可高估。
Future<ImageParams> resolveFocusedBillingParams(
  ImageParams params,
  GenerationFocusedSnapshot focused,
) async {
  if (!focused.enabled || !params.isInpainting) {
    return params;
  }
  final geometry = await FocusedInpaintUtils.resolveRequestGeometryAsync(
    sourceImage: params.sourceImage!,
    maskImage: params.maskImage!,
    focusedSelectionRect: focused.selectionRect,
    contextCrop: focused.contextCrop,
    minContextMegaPixels: focused.minimumContextMegaPixels,
  );
  return geometry == null
      ? params
      : params.copyWith(
          width: geometry.requestWidth,
          height: geometry.requestHeight,
        );
}
