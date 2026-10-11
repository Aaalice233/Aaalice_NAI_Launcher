import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_sse_line_decoder.dart';

void main() {
  group('McpSseLineDecoder', () {
    test('decodes a single data line terminated by a blank line', () {
      final decoder = McpSseLineDecoder();

      final messages = decoder.addChunk(
        'event: message\ndata: {"jsonrpc":"2.0","id":1,"result":{}}\n\n',
      );

      expect(messages, [
        {'jsonrpc': '2.0', 'id': 1, 'result': <String, Object?>{}},
      ]);
    });

    test('joins multi-line data fields with newlines', () {
      final decoder = McpSseLineDecoder();

      final messages = decoder.addChunk(
        'data: {"jsonrpc":"2.0",\ndata: "id":7,\ndata: "result":{"ok":true}}\n\n',
      );

      expect(messages, [
        {
          'jsonrpc': '2.0',
          'id': 7,
          'result': {'ok': true},
        },
      ]);
    });

    test('ignores comments, keep-alives and non-data fields', () {
      final decoder = McpSseLineDecoder();

      final messages = decoder.addChunk(
        ': keep-alive\n'
        '\n'
        'id: 42\n'
        'retry: 1000\n'
        'event: message\n'
        'data: {"jsonrpc":"2.0","method":"notifications/progress"}\n'
        '\n'
        ': keep-alive\n',
      );

      expect(messages, [
        {'jsonrpc': '2.0', 'method': 'notifications/progress'},
      ]);
    });

    test('tolerates CRLF line endings', () {
      final decoder = McpSseLineDecoder();

      final messages = decoder.addChunk(
        'event: message\r\ndata: {"id":3}\r\n\r\n',
      );

      expect(messages, [
        {'id': 3},
      ]);
    });

    test('reassembles frames split across chunk boundaries', () {
      final decoder = McpSseLineDecoder();

      expect(decoder.addChunk('event: mes'), isEmpty);
      expect(decoder.addChunk('sage\ndata: {"jsonrpc":"2.0",'), isEmpty);
      expect(decoder.addChunk('"id":9,'), isEmpty);
      expect(decoder.addChunk('"result":{"tools":[]}}\n'), isEmpty);
      expect(decoder.addChunk('\n'), [
        {
          'jsonrpc': '2.0',
          'id': 9,
          'result': {'tools': <Object?>[]},
        },
      ]);
    });

    test('emits several frames from one chunk in order', () {
      final decoder = McpSseLineDecoder();

      final messages = decoder.addChunk(
        'event: message\ndata: {"id":1}\n\n'
        'event: message\ndata: {"id":2}\n\n',
      );

      expect(messages, [
        {'id': 1},
        {'id': 2},
      ]);
    });

    test('flush drains a frame that was never terminated', () {
      final decoder = McpSseLineDecoder();

      expect(decoder.addChunk('data: {"id":5}'), isEmpty);
      expect(decoder.flush(), [
        {'id': 5},
      ]);
      expect(decoder.flush(), isEmpty);
    });

    test('throws on a data payload that is not JSON', () {
      final decoder = McpSseLineDecoder();

      expect(
        () => decoder.addChunk('data: not-json\n\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
