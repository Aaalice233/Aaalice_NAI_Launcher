import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test('round-trips every billed and binary generation input', () async {
    final params = ImageParams(
      prompt: 'prompt',
      negativePrompt: 'negative',
      seed: 42,
      nSamples: 3,
      action: ImageGenerationAction.infill,
      sourceImage: Uint8List.fromList([1, 2, 3]),
      maskImage: Uint8List.fromList([4, 5, 6]),
      strength: 0.31,
      noise: 0.12,
      inpaintStrength: 0.81,
      inpaintMaskClosingIterations: 2,
      inpaintMaskExpansionIterations: 3,
      vibeReferencesV4: [
        VibeReference(
          displayName: 'vibe',
          vibeEncoding: 'encoded-vibe',
          rawImageData: Uint8List.fromList([7, 8]),
          strength: 0.45,
          infoExtracted: 0.67,
        ),
      ],
      preciseReferences: [
        PreciseReference(
          image: Uint8List.fromList([9, 10]),
          type: PreciseRefType.style,
          strength: 0.55,
          fidelity: 0.72,
        ),
      ],
      characters: const [
        CharacterPrompt(
          prompt: 'character',
          negativePrompt: 'character negative',
          positionX: 0.25,
          positionY: 0.75,
        ),
      ],
    );

    final snapshot = await ReplicationTaskGenerationSnapshot.encode(
      params,
      batchSize: 3,
    );
    final restored = await ReplicationTaskGenerationSnapshot.decode(snapshot);

    expect(restored.prompt, params.prompt);
    expect(restored.seed, 42);
    expect(restored.nSamples, 3);
    expect(restored.action, ImageGenerationAction.infill);
    expect(restored.sourceImage, params.sourceImage);
    expect(restored.maskImage, params.maskImage);
    expect(restored.inpaintMaskClosingIterations, 2);
    expect(restored.inpaintMaskExpansionIterations, 3);
    expect(restored.vibeReferencesV4.single.vibeEncoding, 'encoded-vibe');
    expect(restored.vibeReferencesV4.single.rawImageData, [7, 8]);
    expect(restored.preciseReferences.single.image, [9, 10]);
    expect(restored.preciseReferences.single.type, PreciseRefType.style);
    expect(restored.characters.single.prompt, 'character');
    expect(restored.characters.single.positionY, 0.75);
    expect(ReplicationTaskGenerationSnapshot.decodeBatchSize(snapshot), 3);
    expect(
      ReplicationTaskGenerationSnapshot.decodeBatchSize(
        await ReplicationTaskGenerationSnapshot.clone(snapshot),
      ),
      3,
    );
  });

  test('persists the snapshot with the queue task JSON', () async {
    final task = ReplicationTask.create(
      prompt: 'persisted',
      generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'persisted', seed: 91),
      ),
    );

    final restored = ReplicationTask.fromJson(task.toJson());

    expect(restored.generationSnapshot, isNotNull);
    expect(
      (await ReplicationTaskGenerationSnapshot.decode(
        restored.generationSnapshot!,
      )).seed,
      91,
    );
  });

  test('normalizes malformed transient values to FormatException', () async {
    final snapshot = await ReplicationTaskGenerationSnapshot.encode(
      const ImageParams(prompt: 'invalid'),
    );
    (snapshot['transient']
            as Map<String, dynamic>)['inpaintMaskClosingIterations'] =
        'invalid';

    await expectLater(
      ReplicationTaskGenerationSnapshot.decode(snapshot),
      throwsFormatException,
    );
  });

  group('focused inpaint state', () {
    const focused = QueuedFocusedInpaint(
      enabled: true,
      contextPadding: 120,
      selectionRect: Rect.fromLTWH(10, 20, 30, 40),
      contextCrop: Rect.fromLTWH(384, 0, 832, 1216),
    );

    void expectFocused(QueuedFocusedInpaint? actual) {
      expect(actual, isNotNull);
      expect(actual!.enabled, isTrue);
      expect(actual.contextPadding, 120);
      expect(actual.selectionRect, const Rect.fromLTWH(10, 20, 30, 40));
      expect(actual.contextCrop, const Rect.fromLTWH(384, 0, 832, 1216));
    }

    test('round-trips through the persisted task JSON', () async {
      final task = ReplicationTask.create(
        prompt: 'focused',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          const ImageParams(prompt: 'focused'),
          focused: focused,
        ),
      );

      final restored = ReplicationTask.fromJson(
        jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
      );

      expectFocused(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          restored.generationSnapshot!,
        ),
      );
    });

    test('survives clone and prompt edits', () async {
      final snapshot = await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'focused'),
        focused: focused,
      );

      expectFocused(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          await ReplicationTaskGenerationSnapshot.clone(snapshot),
        ),
      );
      expectFocused(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          await ReplicationTaskGenerationSnapshot.withTaskText(
            snapshot,
            prompt: 'edited',
            negativePrompt: 'edited negative',
          ),
        ),
      );
    });

    test('is absent from snapshots written before it existed', () async {
      final legacy = await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'legacy'),
      );

      expect(legacy.containsKey('focused'), isFalse);
      expect(ReplicationTaskGenerationSnapshot.decodeFocused(legacy), isNull);
      expect(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          await ReplicationTaskGenerationSnapshot.clone(legacy),
        ),
        isNull,
      );
    });

    test('rejects malformed rectangles', () async {
      final snapshot = await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'focused'),
        focused: focused,
      );
      (snapshot['focused'] as Map<String, dynamic>)['contextCrop'] = [1, 2];

      expect(
        () => ReplicationTaskGenerationSnapshot.decodeFocused(snapshot),
        throwsFormatException,
      );
    });
  });

  group('large payload conversion', () {
    const focused = QueuedFocusedInpaint(
      enabled: true,
      contextPadding: 1.5,
      selectionRect: Rect.fromLTWH(1, 2, 300, 400),
      contextCrop: Rect.fromLTWH(0, 0, 640.5, 480),
    );
    final params = ImageParams(
      prompt: '1girl, "quoted"\n中文 😀',
      negativePrompt: 'bad\tthings',
      seed: 42,
      action: ImageGenerationAction.infill,
      sourceImage: _bytes(300 * 1024, 1),
      maskImage: _bytes(5000, 2),
      inpaintMaskClosingIterations: 2,
      isOutpaint: true,
      upscaledEnhance: true,
      vibeReferencesV4: [
        VibeReference(
          displayName: 'raw',
          vibeEncoding: '',
          rawImageData: _bytes(70000, 3),
          strength: 0.4,
        ),
        const VibeReference(
          displayName: 'encoded',
          vibeEncoding: 'QUJD',
          sourceType: VibeSourceType.naiv4vibe,
          enabled: false,
        ),
      ],
      preciseReferences: [
        PreciseReference(
          image: _bytes(80000, 4),
          type: PreciseRefType.characterAndStyle,
          strength: 0.8,
          fidelity: 0.3,
        ),
      ],
      characters: const [
        CharacterPrompt(
          prompt: 'char',
          negativePrompt: 'neg',
          positionX: 0.1,
          positionY: 0.9,
          position: 'A5',
        ),
      ],
    );

    test('keeps the persisted JSON byte-for-byte', () async {
      final snapshot = await ReplicationTaskGenerationSnapshot.encode(
        params,
        batchSize: 2,
        focused: focused,
      );

      expect(jsonEncode(snapshot), jsonEncode(_persistedFormat(params)));
    });

    test('round-trips, clones and edits text off the caller', () async {
      final snapshot = await ReplicationTaskGenerationSnapshot.encode(
        params,
        batchSize: 2,
        focused: focused,
      );

      final restored = await ReplicationTaskGenerationSnapshot.decode(snapshot);
      expect(restored.sourceImage, params.sourceImage);
      expect(restored.maskImage, params.maskImage);
      expect(restored.vibeReferencesV4.first.rawImageData, _bytes(70000, 3));
      expect(restored.preciseReferences.single.image, _bytes(80000, 4));
      expect(restored.isOutpaint, isTrue);
      expect(
        jsonEncode(await ReplicationTaskGenerationSnapshot.clone(snapshot)),
        jsonEncode(snapshot),
      );
      final edited = await ReplicationTaskGenerationSnapshot.withTaskText(
        snapshot,
        prompt: 'edited',
        negativePrompt: 'edited negative',
      );
      expect(
        jsonEncode(edited),
        jsonEncode(
          _persistedFormat(
            params.copyWith(
              prompt: 'edited',
              negativePrompt: 'edited negative',
            ),
          ),
        ),
      );
    });

    test(
      'waits for the compute gate while small payloads stay inline',
      () async {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final blocker = Completer<void>();
        final occupied = gate.run(() => blocker.future);
        addTearDown(() async {
          if (!blocker.isCompleted) blocker.complete();
          await occupied;
        });

        var largeDone = false;
        final large = ReplicationTaskGenerationSnapshot.encode(
          params,
          gate: gate,
        ).whenComplete(() => largeDone = true);
        final small = await ReplicationTaskGenerationSnapshot.encode(
          const ImageParams(prompt: 'small'),
          gate: gate,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(small['params'], containsPair('prompt', 'small'));
        expect(largeDone, isFalse);
        blocker.complete();
        expect((await large)['sourceImage'], base64Encode(params.sourceImage!));
      },
    );

    test(
      'reports malformed snapshots as FormatException across isolates',
      () async {
        final valid = await ReplicationTaskGenerationSnapshot.encode(params);
        final snapshot = Map<String, dynamic>.of(valid)
          ..['transient'] = {
            ...valid['transient'] as Map<String, dynamic>,
            'inpaintMaskClosingIterations': 'invalid',
          };
        final corruptImage = Map<String, dynamic>.of(valid)
          ..['sourceImage'] = '${valid['sourceImage']}!';

        final matchesInline = isA<FormatException>().having(
          (error) => '$error',
          'message',
          'FormatException: Invalid queue generation snapshot',
        );
        await expectLater(
          ReplicationTaskGenerationSnapshot.decode(snapshot),
          throwsA(matchesInline),
        );
        await expectLater(
          ReplicationTaskGenerationSnapshot.clone(snapshot),
          throwsA(matchesInline),
        );
        await expectLater(
          ReplicationTaskGenerationSnapshot.withTaskText(
            snapshot,
            prompt: 'edited',
            negativePrompt: '',
          ),
          throwsA(matchesInline),
        );
        await expectLater(
          ReplicationTaskGenerationSnapshot.decode(corruptImage),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Invalid image data',
            ),
          ),
        );
      },
    );

    test('measures persisted bytes like utf8.encode(jsonEncode())', () async {
      final large = await ReplicationTaskGenerationSnapshot.encode(params);
      final text = await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: '"esc"\\ \u0001 中文 😀 \ud800 lone'),
      );

      final sizes =
          await ReplicationTaskGenerationSnapshot.measurePersistedBytes([
            large,
            text,
            large,
          ]);

      expect(sizes, [
        utf8.encode(jsonEncode(large)).length,
        utf8.encode(jsonEncode(text)).length,
        utf8.encode(jsonEncode(large)).length,
      ]);
    });
  });
}

Uint8List _bytes(int length, int seed) => Uint8List.fromList([
  for (var index = 0; index < length; index++) (index * 31 + seed) & 0xff,
]);

// 持久化格式的独立描述，键序与取值都必须与历史快照一致
Map<String, dynamic> _persistedFormat(ImageParams params) => {
  'schemaVersion': 1,
  'batchSize': 2,
  'focused': {
    'enabled': true,
    'contextPadding': 1.5,
    'selectionRect': [1.0, 2.0, 300.0, 400.0],
    'contextCrop': [0.0, 0.0, 640.5, 480.0],
  },
  'params': params.toJson(),
  'transient': {
    'omitQualityTagHint': params.omitQualityTagHint,
    'omitUcPresetTagHint': params.omitUcPresetTagHint,
    'upscaledEnhance': params.upscaledEnhance,
    'isEnhanceRequest': params.isEnhanceRequest,
    'inpaintMaskClosingIterations': params.inpaintMaskClosingIterations,
    'inpaintMaskExpansionIterations': params.inpaintMaskExpansionIterations,
    'isOutpaint': params.isOutpaint,
  },
  'sourceImage': base64Encode(params.sourceImage!),
  'maskImage': base64Encode(params.maskImage!),
  'vibeReferences': [
    for (final reference in params.vibeReferencesV4)
      {
        'value': reference.toJson(),
        if (reference.rawImageData != null)
          'rawImageData': base64Encode(reference.rawImageData!),
      },
  ],
  'preciseReferences': [
    for (final reference in params.preciseReferences)
      {
        'image': base64Encode(reference.image),
        'type': reference.type.name,
        'strength': reference.strength,
        'fidelity': reference.fidelity,
        'enabled': reference.enabled,
      },
  ],
  'characters': [
    for (final character in params.characters)
      {
        'prompt': character.prompt,
        'negativePrompt': character.negativePrompt,
        'positionX': character.positionX,
        'positionY': character.positionY,
        'position': character.position,
      },
  ],
};
