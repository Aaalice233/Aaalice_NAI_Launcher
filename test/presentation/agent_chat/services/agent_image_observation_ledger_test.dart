import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_image_observation_ledger.dart';

AgentToolResult _imageResult(List<String> files) => AgentToolResult(
  content: [
    const ToolResultTextContent('Read image file [image/png]'),
    const ToolResultImageContent(
      ImageContent(
        source: ImageSource.base64(mimeType: 'image/png', base64Data: 'AA=='),
      ),
    ),
  ],
  details: <String, dynamic>{'files': files},
);

AgentToolResult _textResult(List<String> files) => AgentToolResult(
  content: [const ToolResultTextContent('1\thello')],
  details: <String, dynamic>{'files': files},
);

void main() {
  late AgentImageObservationLedger ledger;

  setUp(() => ledger = AgentImageObservationLedger());

  test('records a path only when the result carries image content', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\a.png']));
    ledger.recordToolResult('s1', _textResult([r'C:\work\notes.txt']));

    expect(ledger.hasObserved('s1', r'C:\work\a.png'), isTrue);
    expect(ledger.hasObserved('s1', r'C:\work\notes.txt'), isFalse);
  });

  test('normalizes separators and case so both entry points agree', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\sub\a.png']));

    expect(ledger.hasObserved('s1', r'C:/work/sub/a.png'), isTrue);
    expect(ledger.hasObserved('s1', r'C:\work\sub\..\sub\a.png'), isTrue);
  });

  test('keeps sessions isolated', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\a.png']));

    expect(ledger.hasObserved('s2', r'C:\work\a.png'), isFalse);
    ledger.forgetSession('s1');
    expect(ledger.hasObserved('s1', r'C:\work\a.png'), isFalse);
  });

  test('ignores failed reads and malformed details', () {
    final failed = _imageResult([r'C:\work\a.png'])..isError = true;
    ledger.recordToolResult('s1', failed);
    ledger.recordToolResult(
      's1',
      AgentToolResult(
        content: [
          const ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: 'image/png',
                base64Data: 'AA==',
              ),
            ),
          ),
        ],
        details: 'not-a-map',
      ),
    );

    expect(ledger.hasObserved('s1', r'C:\work\a.png'), isFalse);
  });

  group('ImageObservingAgentTool', () {
    test(
      'forwards the result and records it under the active session',
      () async {
        final inner = _FakeTool(_imageResult([r'C:\work\a.png']));
        var session = 's1';
        final tool = ImageObservingAgentTool(
          inner,
          ledger: ledger,
          activeSessionId: () => session,
        );

        final result = await tool.execute('call-1', const {'path': 'a.png'});

        expect(identical(result, inner.result), isTrue);
        expect(tool.name, equals(inner.name));
        expect(ledger.hasObserved('s1', r'C:\work\a.png'), isTrue);

        session = 's2';
        expect(ledger.hasObserved('s2', r'C:\work\a.png'), isFalse);
      },
    );
  });
}

class _FakeTool extends AgentTool {
  _FakeTool(this.result)
    : super(
        name: 'read',
        description: 'fake',
        parameters: const {'type': 'object'},
        label: 'Read',
      );

  final AgentToolResult result;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async => result;
}
