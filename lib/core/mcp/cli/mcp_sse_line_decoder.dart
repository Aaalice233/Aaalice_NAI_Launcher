import 'dart:convert';

/// Incremental `text/event-stream` reader that yields the JSON-RPC messages
/// carried by `data:` fields. Comments, `event`/`id`/`retry` fields and
/// keep-alives are dropped.
class McpSseLineDecoder {
  final StringBuffer _pending = StringBuffer();
  final List<String> _data = <String>[];

  /// Feeds one chunk of the response body; chunks may split lines anywhere.
  List<Map<String, Object?>> addChunk(String chunk) {
    final messages = <Map<String, Object?>>[];
    _pending.write(chunk);
    final buffered = _pending.toString();
    _pending.clear();
    var start = 0;
    while (true) {
      final newline = buffered.indexOf('\n', start);
      if (newline < 0) {
        _pending.write(buffered.substring(start));
        return messages;
      }
      _handleLine(
        _stripCarriageReturn(buffered.substring(start, newline)),
        messages,
      );
      start = newline + 1;
    }
  }

  /// Drains the trailing frame. The SSE spec discards it, but servers that
  /// close right after the final `data:` line would otherwise lose a response.
  List<Map<String, Object?>> flush() {
    final messages = <Map<String, Object?>>[];
    if (_pending.isNotEmpty) {
      final remainder = _pending.toString();
      _pending.clear();
      _handleLine(_stripCarriageReturn(remainder), messages);
    }
    _dispatch(messages);
    return messages;
  }

  void _handleLine(String line, List<Map<String, Object?>> messages) {
    if (line.isEmpty) {
      _dispatch(messages);
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    if (field != 'data') {
      return;
    }
    if (separator < 0) {
      _data.add('');
      return;
    }
    var value = line.substring(separator + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }
    _data.add(value);
  }

  void _dispatch(List<Map<String, Object?>> messages) {
    if (_data.isEmpty) {
      return;
    }
    final payload = _data.join('\n');
    _data.clear();
    if (payload.trim().isEmpty) {
      return;
    }
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, Object?>) {
      messages.add(decoded);
    }
  }

  static String _stripCarriageReturn(String line) =>
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}
