import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';
import 'package:nai_launcher/core/windowing/agent_window_runtime.dart';

void main() {
  test('snapshot updates retain referenced image assets already published', () {
    const previous = AgentWindowSnapshot(
      revision: 1,
      payload: {
        'imageAssets': {
          'keep': {'base64': 'first'},
          'remove': {'base64': 'old'},
        },
      },
    );
    const next = AgentWindowSnapshot(
      revision: 2,
      payload: {
        'imageAssets': {
          'new': {'base64': 'second'},
        },
        'referencedImageAssets': ['keep', 'new'],
      },
    );

    final merged = mergeAgentWindowSnapshotAssets(previous, next);

    expect(merged.revision, 2);
    expect(merged.payload['imageAssets'], {
      'keep': {'base64': 'first'},
      'new': {'base64': 'second'},
    });
  });
}
