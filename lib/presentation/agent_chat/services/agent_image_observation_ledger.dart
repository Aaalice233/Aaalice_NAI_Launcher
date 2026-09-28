import 'package:path/path.dart' as p;

import '../../../core/agent/agent_types.dart';

/// 记录模型真正以视觉输入收到过的图片，按会话隔离。
///
/// 应用不检测模型视觉能力，缺了这道台账，Agent 可能没看图就凭结果里的 size
/// 字段编出坐标，最终花 Anlas 重绘错位置。
class AgentImageObservationLedger {
  final Map<String, Set<String>> _observedBySession = {};

  /// 判据是结果里是否真的挂了图片内容：读文本不会产生 [ToolResultImageContent]。
  void recordToolResult(String sessionId, AgentToolResult result) {
    if (result.isError) return;
    if (!result.content.any((item) => item is ToolResultImageContent)) return;
    final details = result.details;
    if (details is! Map) return;
    final files = details['files'];
    if (files is! List) return;
    for (final file in files) {
      if (file is String && file.trim().isNotEmpty) {
        _observedBySession.putIfAbsent(sessionId, () => {}).add(_key(file));
      }
    }
  }

  bool hasObserved(String sessionId, String absolutePath) =>
      _observedBySession[sessionId]?.contains(_key(absolutePath)) ?? false;

  void forgetSession(String sessionId) => _observedBySession.remove(sessionId);

  void clear() => _observedBySession.clear();

  static String _key(String path) => p.canonicalize(path);
}

/// 转发工具调用，并把成功返回图片的那次调用记进 [AgentImageObservationLedger]。
class ImageObservingAgentTool extends AgentTool {
  ImageObservingAgentTool(
    AgentTool inner, {
    required AgentImageObservationLedger ledger,
    required String Function() activeSessionId,
  }) : _inner = inner,
       _ledger = ledger,
       _activeSessionId = activeSessionId,
       super(
         name: inner.name,
         description: inner.description,
         parameters: inner.parameters,
         label: inner.label,
       );

  final AgentTool _inner;
  final AgentImageObservationLedger _ledger;
  final String Function() _activeSessionId;

  @override
  Map<String, dynamic> prepareArguments(Map<String, dynamic> args) =>
      _inner.prepareArguments(args);

  @override
  ToolExecutionMode? get executionMode => _inner.executionMode;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final result = await _inner.execute(toolCallId, params, signal, onUpdate);
    _ledger.recordToolResult(_activeSessionId(), result);
    return result;
  }
}
