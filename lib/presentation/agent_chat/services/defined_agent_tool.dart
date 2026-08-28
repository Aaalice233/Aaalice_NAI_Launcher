import 'dart:convert';

import '../../../core/agent/agent_types.dart';

/// Small adapter used by product Toolboxes to declare a schema and executor.
class DefinedAgentTool extends AgentTool {
  DefinedAgentTool({
    required super.name,
    required super.description,
    required Map<String, dynamic> parameters,
    required super.label,
    this.executionModeOverride,
    Future<AgentToolResult> Function(
      String toolCallId,
      Map<String, dynamic> params,
    )?
    executeFn,
    Future<AgentToolResult> Function(
      String toolCallId,
      Map<String, dynamic> params,
      AbortSignal? signal,
      AgentToolUpdateCallback? onUpdate,
    )?
    executeWithControl,
  }) : assert(
         executeFn != null || executeWithControl != null,
         'Provide executeFn or executeWithControl',
       ),
       _executeFn =
           executeFn ??
           ((toolCallId, params) async => AgentToolResult(
             content: const [ToolResultTextContent('Tool not configured.')],
             details: const <String, dynamic>{},
             isError: true,
           )),
       _executeWithControl = executeWithControl,
       super(parameters: _strictToolParameters(parameters));

  final ToolExecutionMode? executionModeOverride;
  final Future<AgentToolResult> Function(
    String toolCallId,
    Map<String, dynamic> params,
  )
  _executeFn;
  final Future<AgentToolResult> Function(
    String toolCallId,
    Map<String, dynamic> params,
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  )?
  _executeWithControl;

  @override
  ToolExecutionMode? get executionMode => executionModeOverride;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    throwIfAborted(signal);
    final controlled = _executeWithControl;
    return controlled != null
        ? controlled(toolCallId, params, signal, onUpdate)
        : _executeFn(toolCallId, params);
  }
}

Map<String, dynamic> _strictToolParameters(Map<String, dynamic> parameters) {
  if (parameters['type'] != 'object' ||
      parameters.containsKey('additionalProperties')) {
    return parameters;
  }
  return {...parameters, 'additionalProperties': false};
}

AgentToolResult agentToolJsonResult(Map<String, dynamic> value) {
  return AgentToolResult(
    content: [ToolResultTextContent(jsonEncode(value))],
    details: value,
  );
}

AgentToolResult agentToolError(String code, String message) {
  final details = <String, dynamic>{
    'ok': false,
    'code': code,
    'message': message,
  };
  return AgentToolResult(
    content: [ToolResultTextContent(jsonEncode(details))],
    details: details,
    isError: true,
  );
}
