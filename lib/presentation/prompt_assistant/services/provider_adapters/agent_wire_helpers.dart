import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';

/// SSE（Server-Sent Events）增量解析器。
///
/// 以字节块喂入，按 LF 分行（仅 `\n`，符合 SSE 规范；容忍结尾 `\r`），
/// 空行界定一个事件，聚合 `event:`/`data:` 行后回调。
/// 字节缓冲保证跨块的 UTF-8 多字节字符不会在行中间被截断解码。
class AgentSseParser {
  final void Function(String event, String data) onEvent;

  AgentSseParser({required this.onEvent});

  final BytesBuilder _bytes = BytesBuilder(copy: false);
  String? _pendingEventName;
  final List<String> _dataLines = [];

  /// 喂入一个字节块，可能触发零或多个事件回调。
  void push(Uint8List chunk) {
    var start = 0;
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] == 0x0A) {
        var end = i;
        if (end > start && chunk[end - 1] == 0x0D) {
          end--;
        }
        _bytes.add(Uint8List.sublistView(chunk, start, end));
        _handleLine(utf8.decode(_bytes.takeBytes(), allowMalformed: true));
        start = i + 1;
      }
    }
    if (start < chunk.length) {
      _bytes.add(Uint8List.sublistView(chunk, start));
    }
  }

  /// 流结束时调用，冲刷缓冲中的最后一行。
  void close() {
    final remaining = _bytes.takeBytes();
    if (remaining.isNotEmpty) {
      _handleLine(utf8.decode(remaining, allowMalformed: true));
    }
    if (_dataLines.isNotEmpty) {
      _dispatch();
    }
  }

  void _handleLine(String rawLine) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }
    switch (field) {
      case 'event':
        _pendingEventName = value;
      case 'data':
        _dataLines.add(value);
    }
  }

  void _dispatch() {
    if (_dataLines.isNotEmpty) {
      onEvent(_pendingEventName ?? '', _dataLines.join('\n'));
    }
    _pendingEventName = null;
    _dataLines.clear();
  }
}

/// 把 dio/网络异常映射为线错误事件。
AgentWireError agentWireErrorFrom(Object error, ProviderConfig provider) {
  if (error is DioException) {
    if (error.type == DioExceptionType.cancel) {
      return const AgentWireError('aborted');
    }
    final status = error.response?.statusCode;
    final detail = _extractDetail(error.response?.data) ?? error.message ?? '';
    final transient = status == 429 ||
        (status != null && status >= 500) ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError;
    final lowered = detail.toLowerCase();
    final overloaded = lowered.contains('overloaded') ||
        lowered.contains('rate limit');
    return AgentWireError(
      'LLM request failed'
      '${status != null ? ': HTTP $status' : ''}'
      ': provider=${provider.name}'
      '${detail.trim().isNotEmpty ? ': $detail' : ''}',
      transient: transient || overloaded,
    );
  }
  return AgentWireError('LLM request failed: provider=${provider.name}: '
      '${error.toString()}');
}

String? _extractDetail(dynamic data) {
  if (data is Map) {
    if (data['error'] is Map) {
      final message = data['error']['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    if (data['error'] is String) {
      return data['error'] as String;
    }
    if (data['message'] is String) {
      return data['message'] as String;
    }
  }
  if (data is String && data.trim().isNotEmpty) {
    return data;
  }
  return null;
}

/// 解析一条 SSE data 为 JSON 对象；非 JSON 返回 null。
Map<String, dynamic>? parseSseJson(String data) {
  final trimmed = data.trim();
  if (trimmed.isEmpty || trimmed == '[DONE]') {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // 忽略无法解析的行（例如供应商插入的注释/非 JSON 心跳）。
  }
  return null;
}

/// 流式 POST：返回 SSE 字节流。
Stream<Uint8List> agentStreamPost(
  Dio dio, {
  required String endpoint,
  required Object payload,
  required Map<String, dynamic> headers,
  required CancelToken cancelToken,
}) async* {
  final response = await dio.post<ResponseBody>(
    endpoint,
    data: payload,
    options: Options(
      headers: headers,
      responseType: ResponseType.stream,
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ),
    cancelToken: cancelToken,
  );
  final body = response.data;
  if (body == null) {
    throw StateError('LLM stream response is empty: $endpoint');
  }
  yield* body.stream.cast<Uint8List>();
}

/// 宽松地把工具参数 JSON 字符串解析为 Map；失败返回空 Map。
Map<String, dynamic> parseToolArguments(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return const {};
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // 参数非法时按空参数处理，由工具执行层报错并让模型重试。
  }
  return const {};
}
