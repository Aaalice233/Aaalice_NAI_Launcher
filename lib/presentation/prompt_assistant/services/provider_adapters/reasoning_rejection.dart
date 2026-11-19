import 'package:dio/dio.dart';

String? rejectedReasoningField(DioException error) {
  final status = error.response?.statusCode;
  if (status != 400 && status != 422) return null;
  return _rejectedField(error.response?.data, error.requestOptions.data);
}

String? _rejectedField(Object? body, Object? payload) {
  if (payload is! Map) return null;
  final fields = _sentReasoningFields(payload).toList();
  for (final item in _errorItems(body)) {
    final parameter = item is Map ? item['param'] ?? item['loc'] : null;
    if (parameter is String || parameter is List) {
      final path = _normalize(
        parameter is List
            ? parameter.where((part) => part != 'body').join('.')
            : parameter as String,
      );
      final match = fields
          .where(
            (field) =>
                _fieldNames(field).contains(path) ||
                (path.contains('.') && _normalize(field).endsWith('.$path')),
          )
          .firstOrNull;
      if (match != null) return match;
      continue;
    }
    final message = item is Map ? item['message'] ?? item['msg'] : item;
    if (message is! String) continue;
    final text = _normalize(message);
    if (!_rejection.hasMatch(text) || _unknownModel.hasMatch(text)) continue;
    for (final field in fields) {
      for (final alias in _fieldNames(field)) {
        if (_mentionsField(text, alias)) return field;
      }
    }
  }
  return null;
}

bool _mentionsField(String message, String name) {
  const parameterName =
      r'''(?:parameter|field|argument|property|key|name)\s*[:=]?\s*["'`]?''';
  const wordStart = r'(?<![a-z0-9_.-])';
  const wordEnd = r'(?![a-z0-9_-]|\.[a-z0-9_])';
  final prefix = const {'reasoning', 'thinking', 'include'}.contains(name)
      ? parameterName
      : wordStart;
  return RegExp('$prefix${RegExp.escape(name)}$wordEnd').hasMatch(message);
}

final _unknownModel = RegExp(
  r'''\b(?:unknown|invalid|unsupported) model(?: id)?\s*[:=]?\s+["'`]''',
);

Iterable<Object?> _errorItems(Object? body) sync* {
  if (body case {'error': final error?}) {
    yield* _errorItems(error);
  } else if (body case {'detail': final List items}) {
    for (final item in items) {
      yield* _errorItems(item);
    }
  } else {
    yield body;
  }
}

String? providerErrorDetail(Object? body) {
  final messages = [
    for (final item in _errorItems(body))
      if ((item is Map
              ? item['message'] ?? item['msg'] ?? item['detail'] ?? item['type']
              : item)
          case final String message when message.trim().isNotEmpty)
        message,
  ];
  return messages.isEmpty ? null : messages.join('\n');
}

class ProviderResponseError extends StateError {
  ProviderResponseError(Object body, Object? payload)
    : field = _rejectedField(body, payload),
      super(providerErrorDetail(body) ?? body.toString());

  final String? field;

  String describe(String provider, String model) =>
      'LLM service returned an error: provider=$provider, model=$model: $message';
}

dynamic checkedProviderResponse(Response<dynamic> response) {
  final body = response.data;
  if (body case {'error': final error?}) {
    throw ProviderResponseError(error, response.requestOptions.data);
  }
  return body;
}

Set<String> _fieldNames(String field) {
  final name = _normalize(field);
  final leaf = name.split('.').last;
  return {
    name,
    if (leaf != 'type' && leaf != 'display') leaf,
    if (leaf.contains('_')) leaf.replaceAll('_', ' '),
    if (leaf == 'reasoning_effort' ||
        leaf == 'effort' ||
        leaf == 'thinking_level') ...{
      'reasoning level',
      'thinking level',
    },
  };
}

Iterable<String> _sentReasoningFields(Map payload) sync* {
  for (final name in [
    'reasoning_effort',
    'reasoning',
    'thinking',
    'output_config',
    'enable_thinking',
    'prompt_mode',
  ]) {
    if (!payload.containsKey(name)) continue;
    final value = payload[name];
    if (value is Map) {
      for (final key in value.keys) {
        yield '$name.$key';
      }
    }
    yield name;
  }
  if (payload['generationConfig'] case {'thinkingConfig': final Map thinking}) {
    for (final key in thinking.keys) {
      yield 'generationConfig.thinkingConfig.$key';
    }
    yield 'generationConfig.thinkingConfig';
  }
  if (payload['include'] case final List include
      when include.contains('reasoning.encrypted_content')) {
    yield 'reasoning.encrypted_content';
    yield 'include';
  }
}

String _normalize(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

final _rejection = RegExp(
  r'unsupported|not support|not (?:allowed|permitted|available|recognized)|invalid|unknown|unrecogni[sz]ed|unexpected|must be|supported values|only (?:accepts|supports)|not one of|extra_forbidden|不支持|无效|不支援|無效|未対応',
);

String reasoningRejectionMessage(String message, String field, String? hint) =>
    [message, hint == null ? field : '$field · $hint'].join('\n');
