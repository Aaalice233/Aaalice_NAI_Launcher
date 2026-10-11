import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test('round-trips every billed and binary generation input', () {
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

    final snapshot = ReplicationTaskGenerationSnapshot.encode(
      params,
      batchSize: 3,
    );
    final restored = ReplicationTaskGenerationSnapshot.decode(snapshot);

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
        ReplicationTaskGenerationSnapshot.clone(snapshot),
      ),
      3,
    );
  });

  test('persists the snapshot with the queue task JSON', () {
    final task = ReplicationTask.create(
      prompt: 'persisted',
      generationSnapshot: ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'persisted', seed: 91),
      ),
    );

    final restored = ReplicationTask.fromJson(task.toJson());

    expect(restored.generationSnapshot, isNotNull);
    expect(
      ReplicationTaskGenerationSnapshot.decode(
        restored.generationSnapshot!,
      ).seed,
      91,
    );
  });

  test('normalizes malformed transient values to FormatException', () {
    final snapshot = ReplicationTaskGenerationSnapshot.encode(
      const ImageParams(prompt: 'invalid'),
    );
    (snapshot['transient']
            as Map<String, dynamic>)['inpaintMaskClosingIterations'] =
        'invalid';

    expect(
      () => ReplicationTaskGenerationSnapshot.decode(snapshot),
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

    test('round-trips through the persisted task JSON', () {
      final task = ReplicationTask.create(
        prompt: 'focused',
        generationSnapshot: ReplicationTaskGenerationSnapshot.encode(
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

    test('survives clone and prompt edits', () {
      final snapshot = ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'focused'),
        focused: focused,
      );

      expectFocused(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          ReplicationTaskGenerationSnapshot.clone(snapshot),
        ),
      );
      expectFocused(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          ReplicationTaskGenerationSnapshot.withTaskText(
            snapshot,
            prompt: 'edited',
            negativePrompt: 'edited negative',
          ),
        ),
      );
    });

    test('is absent from snapshots written before it existed', () {
      final legacy = ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'legacy'),
      );

      expect(legacy.containsKey('focused'), isFalse);
      expect(ReplicationTaskGenerationSnapshot.decodeFocused(legacy), isNull);
      expect(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          ReplicationTaskGenerationSnapshot.clone(legacy),
        ),
        isNull,
      );
    });

    test('rejects malformed rectangles', () {
      final snapshot = ReplicationTaskGenerationSnapshot.encode(
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
}
