import 'agent_types.dart';

/// 工具参数校验
/// 子集实现：type/properties/required/enum/items）。校验失败抛出
/// [FormatException]，由 loop 捕获并转为错误工具结果让模型重试。
Map<String, dynamic> validateToolArguments(
  AgentTool tool,
  ToolCallContent toolCall,
) {
  final args = tool.prepareArguments(toolCall.arguments);
  _validateAgainstSchema(
    args,
    tool.parameters,
    path: tool.name,
  );
  return args;
}

void _validateAgainstSchema(
  Object? value,
  Map<String, dynamic> schema, {
  required String path,
}) {
  final type = schema['type'];
  if (type is String && !_matchesType(value, type)) {
    throw FormatException(
      '$path: expected $type, got ${_typeName(value)}',
    );
  }
  final enumValues = schema['enum'];
  if (enumValues is List && !enumValues.contains(value)) {
    throw FormatException(
      '$path: value must be one of ${enumValues.join(', ')}',
    );
  }
  if (value is Map<String, dynamic>) {
    final required = schema['required'];
    if (required is List) {
      for (final key in required) {
        if (key is String && !value.containsKey(key)) {
          throw FormatException('$path: missing required property "$key"');
        }
      }
    }
    final properties = schema['properties'];
    if (properties is Map<String, dynamic>) {
      for (final entry in properties.entries) {
        if (value.containsKey(entry.key) &&
            entry.value is Map<String, dynamic>) {
          _validateAgainstSchema(
            value[entry.key],
            entry.value as Map<String, dynamic>,
            path: '$path.${entry.key}',
          );
        }
      }
    }
  }
  if (value is List) {
    final items = schema['items'];
    if (items is Map<String, dynamic>) {
      for (var i = 0; i < value.length; i++) {
        _validateAgainstSchema(
          value[i],
          items,
          path: '$path[$i]',
        );
      }
    }
  }
}

bool _matchesType(Object? value, String type) {
  switch (type) {
    case 'string':
      return value is String;
    case 'number':
      return value is num;
    case 'integer':
      return value is int || (value is num && value == value.roundToDouble());
    case 'boolean':
      return value is bool;
    case 'array':
      return value is List;
    case 'object':
      return value is Map;
    case 'null':
      return value == null;
    default:
      return true;
  }
}

String _typeName(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'string';
  if (value is bool) return 'boolean';
  if (value is int) return 'integer';
  if (value is num) return 'number';
  if (value is List) return 'array';
  if (value is Map) return 'object';
  return value.runtimeType.toString();
}
