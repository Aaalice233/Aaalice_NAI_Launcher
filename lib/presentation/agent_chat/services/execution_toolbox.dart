import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/tools/tools_index.dart';

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
  ExecutionToolbox(String workspaceDir, {bool allowOutsideWorkspace = false})
    : _env = DartIoExecutionEnv(
        workingDirectory: workspaceDir,
        allowOutsideWorkingDirectory: allowOutsideWorkspace,
      );

  final ExecutionEnv _env;

  List<AgentTool> tools() {
    final context = ExecutionToolContext(env: _env);
    return [ContextAgentTool(createReadTool(), context)];
  }
}
