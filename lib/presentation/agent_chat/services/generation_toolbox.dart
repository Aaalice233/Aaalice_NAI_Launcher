import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import 'agent_resource_resolver.dart';
import 'generation_anlas_estimator.dart';
import 'generation_execution_service.dart';
import 'generation_history_service.dart';
import 'generation_image_read_contract.dart';
import 'generation_interrogation_service.dart';
import 'generation_preparation_runtime.dart';
import 'generation_preparation_service.dart';
import 'generation_queue_task_service.dart';
import 'generation_settings_service.dart';
import 'generation_source_image_toolbox.dart';
import 'generation_status_service.dart';
import 'generation_tool_definitions.dart';
import 'generation_tool_limits.dart';
import 'generation_workspace_path_resolver.dart';

/// 生成 / 反推工具集的稳定入口。
///
/// Tool 声明和各项业务实现按职责拆分；此类只负责保持构造参数及 [tools]
/// 公共契约，并装配共享的 preparation runtime、资源解析器与工作区路径策略。
class GenerationToolbox {
  GenerationToolbox(
    Ref ref, {
    String? workspaceDir,
    bool allowOutsideWorkspace = false,
    GenerationPreparationRuntime? runtime,
    AgentResourceResolver? resourceResolver,
  }) {
    final preparationRuntime = runtime ?? GenerationPreparationRuntime();
    final resolver = resourceResolver ?? AgentResourceResolver(ref);
    final pathResolver = GenerationWorkspacePathResolver(
      workspaceDir: workspaceDir,
      allowOutsideWorkspace: allowOutsideWorkspace,
    );
    final imageReadContract = GenerationImageReadContract(pathResolver);
    final history = GenerationHistoryService(
      ref,
      imageReadContract: imageReadContract,
      maxRecentImageLimit: maxRecentImageLimit,
    );
    final execution = GenerationExecutionService(
      ref,
      pathResolver: pathResolver,
      imageReadContract: imageReadContract,
      maxGenerateCount: maxGenerateCount,
    );
    final queue = GenerationQueueTaskService(
      ref,
      maxQueueSnapshotBytes: maxQueueSnapshotBytes,
      maxPersistedQueueSnapshotBytes: maxPersistedQueueSnapshotBytes,
    );
    final preparation = GenerationPreparationService(
      ref,
      runtime: preparationRuntime,
      resourceResolver: resolver,
      pathResolver: pathResolver,
      maxGenerateCount: maxGenerateCount,
      anlasEstimator: GenerationAnlasEstimator(ref),
      executeGeneration: execution.generate,
      executeQueue: queue.queueTask,
    );
    _definitions = GenerationToolDefinitions(
      interrogation: GenerationInterrogationService(ref, pathResolver),
      preparation: preparation,
      status: GenerationStatusService(
        ref,
        generatedImageReference: imageReadContract.resourceReference,
      ),
      settings: GenerationSettingsService(ref),
      history: history,
    );
    _sourceImage = GenerationSourceImageToolbox(
      ref,
      resolver: resolver,
      pathResolver: pathResolver,
    );
  }

  static const int maxGenerateCount = generationToolMaxGenerateCount;
  static const int maxRecentImageLimit = generationToolMaxRecentImageLimit;
  static const int maxQueueSnapshotBytes = generationToolMaxQueueSnapshotBytes;
  static const int maxPersistedQueueSnapshotBytes =
      generationToolMaxPersistedQueueSnapshotBytes;

  static bool agentChatSupportsImage({
    required AgentSettings settings,
    required PromptAssistantConfigState promptAssistant,
  }) => GenerationInterrogationService.agentChatSupportsImage(
    settings: settings,
    promptAssistant: promptAssistant,
  );

  late final GenerationToolDefinitions _definitions;
  late final GenerationSourceImageToolbox _sourceImage;

  List<AgentTool> tools() => [..._definitions.tools(), ..._sourceImage.tools()];
}
