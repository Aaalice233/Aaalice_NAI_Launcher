import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_resource_toolbox.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

GeneratedImage _image(
  String id, {
  GeneratedImageKind kind = GeneratedImageKind.completed,
}) => GeneratedImage(
  id: id,
  bytes: Uint8List.fromList(const [1]),
  width: 64,
  height: 64,
  kind: kind,
);

Map<String, Object> _ref(String id, {String source = 'legacy'}) =>
    AgentChatResourceReferenceCodec.encodeJsonMap(
      AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: source,
        resourceId: id,
      ),
    );

void main() {
  test(
    'resource_ref wins over compatibility image_id and is normalized',
    () async {
      final current = _image('current');
      final history = _image('history');
      var selected = '';
      var navigations = 0;
      final service = GenerationResourceService(
        readState: () =>
            ImageGenerationState(currentImages: [current], history: [history]),
        select: (id) => selected = id,
        navigateToGeneration: () => navigations++,
      );

      final result = await service.selectGeneratedImage({
        'resource_ref': _ref('history'),
        'image_id': 'current',
      });

      expect(result.isError, isFalse);
      expect(selected, 'history');
      expect(navigations, 1);
      final reference = result.details['resource_ref'] as Map<String, dynamic>;
      expect(reference['source'], generationImageResourceSource);
      expect(reference['resourceId'], 'history');
    },
  );

  test('resolves IDs from currentImages, history, and displayImages', () {
    final state = ImageGenerationState(
      currentImages: [_image('current')],
      history: [_image('history')],
      displayImages: [_image('display')],
    );

    for (final id in ['current', 'history', 'display']) {
      final reference = parseGenerationImageResource({'image_id': id});
      expect(requireAvailableGenerationImage(state, reference).id, id);
    }
  });

  test(
    'rejects missing, stale, failed snapshot, index, and bare path',
    () async {
      final failed = _image(
        'failed',
        kind: GeneratedImageKind.failedStreamSnapshot,
      );
      final service = GenerationResourceService(
        readState: () => ImageGenerationState(history: [failed]),
        select: (_) => fail('must not select'),
        navigateToGeneration: () => fail('must not navigate'),
      );

      final cases = <Map<String, dynamic>, String>{
        const {}: 'missing_image_resource',
        const {'image_id': 'stale'}: 'stale_image_resource',
        const {'image_id': 'failed'}: 'failed_stream_snapshot',
        const {'index': 0}: 'missing_image_resource',
        const {'path': 'history/image.png'}: 'missing_image_resource',
      };
      for (final entry in cases.entries) {
        final result = await service.selectGeneratedImage(entry.key);
        expect(result.isError, isTrue, reason: '${entry.key}');
        expect(result.details['code'], entry.value, reason: '${entry.key}');
      }
    },
  );

  test(
    'rechecks the ID before mutation after asynchronous resolution',
    () async {
      final gate = Completer<void>();
      var state = ImageGenerationState(history: [_image('late')]);
      var selected = false;
      final service = GenerationResourceService(
        readState: () => state,
        select: (_) => selected = true,
        navigateToGeneration: () => fail('must not navigate'),
        beforeMutation: (_) => gate.future,
      );

      final pending = service.selectGeneratedImage({'image_id': 'late'});
      await Future<void>.delayed(Duration.zero);
      state = const ImageGenerationState();
      gate.complete();
      final result = await pending;

      expect(result.isError, isTrue);
      expect(result.details['code'], 'stale_image_resource');
      expect(selected, isFalse);
    },
  );

  test('navigate false selects without navigation', () async {
    var selected = '';
    var navigated = false;
    final service = GenerationResourceService(
      readState: () => ImageGenerationState(history: [_image('saved')]),
      select: (id) => selected = id,
      navigateToGeneration: () => navigated = true,
    );

    final result = await service.selectGeneratedImage({
      'image_id': 'saved',
      'navigate': false,
    });

    expect(result.isError, isFalse);
    expect(selected, 'saved');
    expect(navigated, isFalse);
    expect(result.details['navigated'], isFalse);
  });
}
