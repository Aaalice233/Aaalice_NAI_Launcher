import 'generation_preparation_runtime.dart';

/// 审批卡只显示已登记事务的目标：没有 preparation id 的调用还没到写盘阶段。
List<String> preparedFileTargets(
  String toolName,
  Map<String, dynamic> args, {
  required GenerationPreparationRuntime generationRuntime,
}) {
  if (toolName == 'submit_generation' || toolName == 'generate_image') {
    final id = args['preparation_id'];
    if (id is! String) return const [];
    final savePath = generationRuntime.get(id)?.savePath;
    return savePath == null || savePath.isEmpty ? const [] : [savePath];
  }
  if (toolName == 'save_generated_image') {
    final destination = args['destination_path'];
    return destination is String && destination.isNotEmpty
        ? [destination]
        : const [];
  }
  return const [];
}
