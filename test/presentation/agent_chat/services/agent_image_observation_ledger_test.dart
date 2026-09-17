import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/utils/display_thumbnail_utils.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_image_observation_ledger.dart';

final _reference = AgentChatResourceReference(
  kind: AgentChatResourceKind.generatedImage,
  source: 'generation_history',
  resourceId: 'generated-1',
  display: const {'label': 'Generated image'},
  provenance: const {'tool': 'generate_image'},
);

ToolResultImageContent _imageContent(int width, int height) =>
    ToolResultImageContent(
      ImageContent(
        source: ImageSource.base64(
          mimeType: 'image/png',
          base64Data: base64Encode(
            Uint8List.fromList(
              img.encodePng(img.Image(width: width, height: height)),
            ),
          ),
        ),
      ),
    );

const _undecodableImage = ToolResultImageContent(
  ImageContent(
    source: ImageSource.base64(mimeType: 'image/png', base64Data: 'AA=='),
  ),
);

AgentToolResult _imageResult(
  List<String> files, {
  int width = 1024,
  int height = 1024,
}) => AgentToolResult(
  content: [
    const ToolResultTextContent('Read image file [image/png]'),
    _imageContent(width, height),
  ],
  details: <String, dynamic>{'files': files},
);

AgentToolResult _textResult(List<String> files) => AgentToolResult(
  content: [const ToolResultTextContent('1\thello')],
  details: <String, dynamic>{'files': files},
);

AgentToolResult _referenceResult(
  List<AgentChatResourceReference> references, {
  List<ToolResultImageContent>? content,
  int width = 1024,
  int height = 1024,
}) => AgentToolResult(
  content:
      content ?? [for (final _ in references) _imageContent(width, height)],
  details: <String, dynamic>{
    'images': <Map<String, dynamic>>[
      for (final reference in references)
        {
          'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
            reference,
          ),
        },
    ],
  },
);

void main() {
  late AgentImageObservationLedger ledger;

  setUp(() => ledger = AgentImageObservationLedger());

  bool observedPath(String path, {int sourceLongSide = 1024}) =>
      ledger.hasObserved('s1', paths: [path], sourceLongSide: sourceLongSide);

  test('records a path only when the result carries image content', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\a.png']));
    ledger.recordToolResult('s1', _textResult([r'C:\work\notes.txt']));

    expect(observedPath(r'C:\work\a.png'), isTrue);
    expect(observedPath(r'C:\work\notes.txt'), isFalse);
  });

  test('normalizes separators and case so both entry points agree', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\sub\a.png']));

    expect(observedPath(r'C:/work/sub/a.png'), isTrue);
    expect(observedPath(r'C:\work\sub\..\sub\a.png'), isTrue);
  });

  test('keeps sessions isolated', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\a.png']));

    expect(
      ledger.hasObserved('s2', paths: [r'C:\work\a.png'], sourceLongSide: 1024),
      isFalse,
    );
    ledger.forgetSession('s1');
    expect(observedPath(r'C:\work\a.png'), isFalse);
  });

  test('ignores failed reads and malformed details', () {
    final failed = _imageResult([r'C:\work\a.png'])..isError = true;
    ledger.recordToolResult('s1', failed);
    ledger.recordToolResult(
      's1',
      AgentToolResult(
        content: [_imageContent(1024, 1024)],
        details: 'not-a-map',
      ),
    );

    expect(observedPath(r'C:\work\a.png'), isFalse);
  });

  test('records the resource_ref identity of returned images', () {
    ledger.recordToolResult('s1', _referenceResult([_reference]));

    expect(
      ledger.hasObserved('s1', references: [_reference], sourceLongSide: 1024),
      isTrue,
    );
  });

  test('matches a reference that lost display and provenance in transit', () {
    ledger.recordToolResult('s1', _referenceResult([_reference]));
    final stripped = AgentChatResourceReference(
      kind: _reference.kind,
      source: _reference.source,
      resourceId: _reference.resourceId,
    );

    expect(stripped, isNot(_reference));
    expect(
      ledger.hasObserved('s1', references: [stripped], sourceLongSide: 1024),
      isTrue,
    );
  });

  test('skips malformed resource_ref entries without losing the rest', () {
    final result = _referenceResult([_reference], width: 900, height: 900);
    (result.details['images'] as List).insert(0, {'resource_ref': 'not-a-map'});
    (result.details['images'] as List).insert(1, {
      'resource_ref': {'version': 1, 'kind': 'nope'},
    });

    ledger.recordToolResult('s1', result);

    expect(
      ledger.hasObserved('s1', references: [_reference], sourceLongSide: 900),
      isTrue,
    );
  });

  group('resolution rule', () {
    test('a 256px thumbnail cannot measure a 1024px source', () {
      ledger.recordToolResult(
        's1',
        _imageResult([r'C:\work\a.png'], width: 256, height: 256),
      );

      expect(observedPath(r'C:\work\a.png'), isFalse);
    });

    test('the source resolution itself is enough', () {
      ledger.recordToolResult(
        's1',
        _imageResult([r'C:\work\a.png'], width: 1024, height: 1024),
      );

      expect(observedPath(r'C:\work\a.png'), isTrue);
    });

    test('a downscaled but above-thumbnail view is enough', () {
      ledger.recordToolResult(
        's1',
        _imageResult([r'C:\work\a.png'], width: 1536, height: 1024),
      );

      expect(observedPath(r'C:\work\a.png', sourceLongSide: 2048), isTrue);
    });

    test('a thumbnail of a tiny source is the source', () {
      ledger.recordToolResult(
        's1',
        _imageResult([r'C:\work\a.png'], width: 200, height: 200),
      );

      expect(observedPath(r'C:\work\a.png', sourceLongSide: 200), isTrue);
    });

    test('the decision only depends on the two long sides', () {
      expect(
        AgentImageObservationLedger.isUsableObservation(
          observedLongSide: DisplayThumbnailUtils.maxDimension,
          sourceLongSide: 1024,
        ),
        isFalse,
      );
      expect(
        AgentImageObservationLedger.isUsableObservation(
          observedLongSide: DisplayThumbnailUtils.maxDimension + 1,
          sourceLongSide: 4096,
        ),
        isTrue,
      );
      expect(
        AgentImageObservationLedger.isUsableObservation(
          observedLongSide: 200,
          sourceLongSide: 200,
        ),
        isTrue,
      );
    });
  });

  test('keeps the largest resolution seen for one identity', () {
    ledger.recordToolResult(
      's1',
      _imageResult([r'C:\work\a.png'], width: 1024, height: 1024),
    );
    ledger.recordToolResult(
      's1',
      _imageResult([r'C:\work\a.png'], width: 256, height: 256),
    );

    expect(observedPath(r'C:\work\a.png'), isTrue);
  });

  test('a multi-image result counts as its smallest long side', () {
    ledger.recordToolResult(
      's1',
      _referenceResult(
        [_reference],
        content: [_imageContent(1024, 1024), _imageContent(256, 256)],
      ),
    );

    expect(
      ledger.hasObserved('s1', references: [_reference], sourceLongSide: 1024),
      isFalse,
    );
    expect(
      ledger.hasObserved('s1', references: [_reference], sourceLongSide: 200),
      isTrue,
    );
  });

  test('one undecodable image discards the whole result', () {
    ledger.recordToolResult(
      's1',
      AgentToolResult(
        content: [_imageContent(1024, 1024), _undecodableImage],
        details: <String, dynamic>{
          'files': [r'C:\work\a.png'],
        },
      ),
    );

    expect(observedPath(r'C:\work\a.png'), isFalse);
  });

  test('path identities and reference identities stay separate', () {
    ledger.recordToolResult('s1', _imageResult([r'C:\work\a.png']));
    ledger.recordToolResult('s1', _referenceResult([_reference]));

    expect(
      ledger.hasObserved(
        's1',
        paths: [_reference.identityKey],
        sourceLongSide: 1024,
      ),
      isFalse,
    );
    expect(
      ledger.hasObserved(
        's1',
        references: [
          AgentChatResourceReference(
            kind: AgentChatResourceKind.localGalleryImage,
            source: 'local_gallery',
            resourceId: '42',
          ),
        ],
        sourceLongSide: 1024,
      ),
      isFalse,
    );
    expect(observedPath(r'C:\work\a.png'), isTrue);
    expect(
      ledger.hasObserved('s1', references: [_reference], sourceLongSide: 1024),
      isTrue,
    );
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
        expect(observedPath(r'C:\work\a.png'), isTrue);

        session = 's2';
        expect(
          ledger.hasObserved(
            's2',
            paths: [r'C:\work\a.png'],
            sourceLongSide: 1024,
          ),
          isFalse,
        );
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
