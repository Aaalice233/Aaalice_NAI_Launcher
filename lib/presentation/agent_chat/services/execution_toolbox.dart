import 'dart:convert';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/tools/tools_index.dart';
import '../../utils/reverse_prompt_image_normalizer.dart';
import 'agent_image_observation_ledger.dart';

/// 把 [AgentHarnessTool]（需要 ExecutionToolContext）适配成 loop 可直接
/// 调用的 [AgentTool]：注入 env 上下文并透传 signal / onUpdate /
/// prepareArguments。
class ContextAgentTool extends AgentTool {
  ContextAgentTool(AgentHarnessTool inner, ExecutionToolContext context)
    : _inner = inner,
      _context = context,
      super(
        name: inner.name,
        description: inner.description,
        parameters: inner.parameters,
        label: inner.label,
      );

  final AgentHarnessTool _inner;
  final ExecutionToolContext _context;

  @override
  Map<String, dynamic> prepareArguments(Map<String, dynamic> args) =>
      _inner.prepareArguments(args);

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    return _inner.executeWithContext(
      toolCallId,
      params,
      signal,
      onUpdate,
      _context,
    );
  }
}

/// pi 执行工具集。
///
/// 当前仅开放 `read`（只读）：write/edit/bash 对桌面客户端风险过高，
/// 已按产品决策禁用；工作目录默认指向图片导出根目录
/// （自定义保存路径或 Documents/NAI_Launcher/images，见
/// AgentChatNotifier._init），相对路径在其下解析，Agent 因此能直接
/// 读取导出的生成图片。
class ExecutionToolbox {
  ExecutionToolbox(
    String workspaceDir, {
    bool allowOutsideWorkspace = false,
    AgentImageObservationLedger? observationLedger,
    String Function()? activeSessionId,
  }) : _env = DartIoExecutionEnv(
         workingDirectory: workspaceDir,
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       ),
       _observationLedger = observationLedger,
       _activeSessionId = activeSessionId;

  final ExecutionEnv _env;
  final AgentImageObservationLedger? _observationLedger;
  final String Function()? _activeSessionId;

  List<AgentTool> tools() {
    final context = ExecutionToolContext(env: _env);
    final read = ContextAgentTool(
      createReadTool(const ReadToolOptions(imageProcessor: _processReadImage)),
      context,
    );
    final ledger = _observationLedger;
    final sessionId = _activeSessionId;
    return [
      // 观察记录挂在这层而不是 harness 的 read 工具里：harness 以 Pi 上游为准，
      // 不得掺入 Launcher 语义。
      if (ledger != null && sessionId != null)
        ImageObservingAgentTool(
          read,
          ledger: ledger,
          activeSessionId: sessionId,
        )
      else
        read,
    ];
  }
}

Future<ReadImageProcessorResult> _processReadImage(
  List<int> bytes,
  String mimeType,
  ({bool autoResizeImages}) options,
) async {
  if (mimeType == 'image/bmp') {
    return const ReadImageProcessorResult.fail(
      'Image omitted: BMP conversion is not supported.',
    );
  }
  try {
    final original = Uint8List.fromList(bytes);
    final processed = options.autoResizeImages
        ? await ReversePromptImageNormalizer.normalize(
            original,
            limits: const ReversePromptImageLimits(
              maxBytes: 4 * 1024 * 1024,
              maxLongSide: 1536,
              maxPixels: 1536 * 1536,
            ),
          )
        : original;
    final processedMime = detectSupportedImageMimeType(processed) ?? mimeType;
    return ReadImageProcessorResult.ok(
      data: base64Encode(processed),
      mimeType: processedMime,
      hints: const [
        'Visual input is constrained to a 1536px long side, 2.36MP, and 4MB.',
      ],
    );
  } catch (error) {
    return ReadImageProcessorResult.fail(
      'Image omitted: failed to prepare visual input ($error).',
    );
  }
}
