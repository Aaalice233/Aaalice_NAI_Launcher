import '../../providers/subscription_billing.dart';
import 'generation_anlas_estimator.dart';
import 'generation_preparation_runtime.dart';
import 'image_upscale_toolbox.dart';
import 'manual_inpaint_toolbox.dart';
import 'queue_toolbox.dart';

/// 生成类计费只认已登记的 preparation，缺少 id 的调用还没进入计费阶段；
/// 单次执行的放大没有事务，按调用参数现算。
///
/// 登记时的估价只在订阅视图未变时沿用，[freshBilling] 负责在过期时先刷新。
Future<int?> estimatePreparedAnlas(
  String toolName,
  Map<String, dynamic> args, {
  required GenerationPreparationRuntime generationRuntime,
  required QueueControlRuntime queueRuntime,
  required ManualInpaintToolbox manualInpaintToolbox,
  required ImageUpscaleToolbox imageUpscaleToolbox,
  required Future<SubscriptionBillingView> Function() freshBilling,
}) async {
  if (toolName == 'submit_generation' ||
      toolName == 'generate_image' ||
      toolName == 'queue_image_task') {
    final id = args['preparation_id'];
    if (id is String) {
      final preparation = generationRuntime.get(id);
      return preparation == null
          ? null
          : _currentGenerationEstimate(preparation, await freshBilling());
    }
  }
  if (toolName == 'submit_manual_inpaint_draft') {
    final id = args['draft_id'];
    return id is String
        ? await manualInpaintToolbox.estimateAnlasForDraft(id)
        : null;
  }
  if (toolName == 'upscale_image') {
    return imageUpscaleToolbox.estimateAnlas(args);
  }
  if (toolName == 'start_generation_queue' ||
      toolName == 'resume_generation_queue') {
    final id = args['queue_preparation_id'];
    final preparation = id is String ? queueRuntime.get(id) : null;
    if (preparation == null) return null;
    // 队列不留存逐个任务的计费参数，订阅视图变了就只能按价格未知请用户确认
    return await freshBilling() == preparation.billing
        ? preparation.estimatedAnlas
        : null;
  }
  return null;
}

int _currentGenerationEstimate(
  GenerationPreparation preparation,
  SubscriptionBillingView billing,
) {
  if (billing == preparation.billing) return preparation.estimatedAnlas;
  return GenerationAnlasEstimator.estimateWithBilling(
    preparation.params,
    requestCount: preparation.requestCount,
    batchSize: preparation.batchSize,
    billing: billing,
  );
}
