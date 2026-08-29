import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';

void main() {
  test('snapshot updates retain referenced image assets already published', () {
    const previous = AgentWindowSnapshot(
      revision: 1,
      payload: {
        'imageAssets': {
          'keep': {'base64': 'Zmlyc3Q='},
          'remove': {'base64': 'b2xk'},
        },
        'referencedImageAssets': ['keep', 'remove'],
      },
    );
    const next = AgentWindowSnapshot(
      revision: 2,
      payload: {
        'imageAssets': {
          'new': {'base64': 'c2Vjb25k'},
        },
        'referencedImageAssets': ['keep', 'new'],
      },
    );

    final merged = mergeAgentWindowSnapshotAssets(previous, next);

    expect(merged.revision, 2);
    expect(merged.payload['imageAssets'], {
      'keep': {'base64': 'Zmlyc3Q='},
      'new': {'base64': 'c2Vjb25k'},
    });
    expect(next.payload['imageAssets'], {
      'new': {'base64': 'c2Vjb25k'},
    });
  });

  test(
    'token snapshot can reference cached assets without carrying base64',
    () {
      const cached = AgentWindowSnapshot(
        revision: 4,
        payload: {
          'imageAssets': {
            'tool-image-1': {'base64': 'bGFyZ2UtcGF5bG9hZA=='},
          },
          'referencedImageAssets': ['tool-image-1'],
        },
      );
      const tokenDelta = AgentWindowSnapshot(
        revision: 5,
        payload: {
          'messages': [
            {'role': 'assistant', 'text': 'next token'},
          ],
          'imageAssets': {},
          'referencedImageAssets': ['tool-image-1'],
        },
      );

      final merged = mergeAgentWindowSnapshotAssets(cached, tokenDelta);

      expect(tokenDelta.payload['imageAssets'], isEmpty);
      expect(merged.payload['imageAssets'], cached.payload['imageAssets']);
    },
  );

  test('snapshot asset release removes bytes no longer referenced', () {
    const cached = AgentWindowSnapshot(
      revision: 6,
      payload: {
        'imageAssets': {
          'released': {'base64': 'Ynl0ZXM='},
        },
        'referencedImageAssets': ['released'],
      },
    );
    const released = AgentWindowSnapshot(
      revision: 7,
      payload: {'imageAssets': {}, 'referencedImageAssets': []},
    );

    final merged = mergeAgentWindowSnapshotAssets(cached, released);

    expect(merged.payload['imageAssets'], isEmpty);
  });

  test('stale revisions and missing one-shot assets fail explicitly', () {
    const current = AgentWindowSnapshot(revision: 9, payload: {});

    expect(
      () => mergeAgentWindowSnapshotAssets(
        current,
        const AgentWindowSnapshot(revision: 8, payload: {}),
      ),
      throwsFormatException,
    );
    expect(
      () => mergeAgentWindowSnapshotAssets(
        current,
        const AgentWindowSnapshot(
          revision: 10,
          payload: {
            'imageAssets': {},
            'referencedImageAssets': ['never-published'],
          },
        ),
      ),
      throwsFormatException,
    );
  });
}
