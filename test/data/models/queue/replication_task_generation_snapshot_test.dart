import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/queue/replication_task_snapshot_blobs.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

import '../../../helpers/memory_queue_blob_store.dart';

void main() {
  late MemoryStorageFileSystem files;
  late ReplicationQueueBlobStore store;

  setUp(() {
    files = MemoryStorageFileSystem();
    store = memoryQueueBlobStore(files);
  });

  Future<Map<String, dynamic>> persisted(
    ImageParams params, {
    int? batchSize,
    QueuedFocusedInpaint? focused,
  }) async {
    final interned = await ReplicationTaskGenerationSnapshot.intern([
      await ReplicationTaskGenerationSnapshot.encode(
        params,
        batchSize: batchSize,
        focused: focused,
      ),
    ], store);
    interned.release();
    // 与写入 Hive 后重新读取的形态一致
    return jsonDecode(jsonEncode(interned.snapshots.single))
        as Map<String, dynamic>;
  }

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
          vibeEncoding: base64Encode(_bytes(300, 9)),
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

    final snapshot = await persisted(params, batchSize: 3);
    final restored = await ReplicationTaskGenerationSnapshot.decode(
      snapshot,
      store,
    );

    expect(restored.prompt, params.prompt);
    expect(restored.seed, 42);
    expect(restored.nSamples, 3);
    expect(restored.action, ImageGenerationAction.infill);
    expect(restored.sourceImage, params.sourceImage);
    expect(restored.maskImage, params.maskImage);
    expect(restored.inpaintMaskClosingIterations, 2);
    expect(restored.inpaintMaskExpansionIterations, 3);
    expect(
      restored.vibeReferencesV4.single.vibeEncoding,
      params.vibeReferencesV4.single.vibeEncoding,
    );
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

  test('persists the snapshot with the queue task JSON', () async {
    final task = ReplicationTask.create(
      prompt: 'persisted',
      generationSnapshot: await persisted(
        const ImageParams(prompt: 'persisted', seed: 91),
      ),
    );

    final restored = ReplicationTask.fromJson(task.toJson());

    expect(restored.generationSnapshot, isNotNull);
    expect(
      (await ReplicationTaskGenerationSnapshot.decode(
        restored.generationSnapshot!,
        store,
      )).seed,
      91,
    );
  });

  test('normalizes malformed transient values to FormatException', () async {
    final snapshot = await persisted(const ImageParams(prompt: 'invalid'));
    (snapshot['transient']
            as Map<String, dynamic>)['inpaintMaskClosingIterations'] =
        'invalid';

    await expectLater(
      ReplicationTaskGenerationSnapshot.decode(snapshot, store),
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
        generationSnapshot: await persisted(
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
      final snapshot = await persisted(
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

    test('is absent from snapshots written without it', () async {
      final snapshot = await persisted(const ImageParams(prompt: 'legacy'));

      expect(snapshot.containsKey('focused'), isFalse);
      expect(ReplicationTaskGenerationSnapshot.decodeFocused(snapshot), isNull);
      expect(
        ReplicationTaskGenerationSnapshot.decodeFocused(
          ReplicationTaskGenerationSnapshot.clone(snapshot),
        ),
        isNull,
      );
    });

    test('rejects malformed rectangles', () async {
      final snapshot = await persisted(
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

  group('image references', () {
    const focused = QueuedFocusedInpaint(
      enabled: true,
      contextPadding: 1.5,
      selectionRect: Rect.fromLTWH(1, 2, 300, 400),
      contextCrop: Rect.fromLTWH(0, 0, 640.5, 480),
    );
    final vibeEncoding = base64Encode(_bytes(48 * 1024, 7));
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
        VibeReference(
          displayName: 'encoded',
          vibeEncoding: vibeEncoding,
          sourceType: VibeSourceType.naiv4vibe,
          enabled: false,
        ),
        const VibeReference(
          displayName: 'not canonical',
          vibeEncoding: 'QUJD\n',
          sourceType: VibeSourceType.naiv4vibe,
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
      final snapshot = await persisted(params, batchSize: 2, focused: focused);

      expect(jsonEncode(snapshot), jsonEncode(_persistedFormat(params)));
    });

    test('names the Vibe value field after the model JSON key', () {
      const reference = VibeReference(displayName: 'v', vibeEncoding: 'QUJD');

      expect(
        reference.toJson(),
        containsPair(vibeReferenceEncodingField, 'QUJD'),
      );
    });

    test('round-trips images byte-for-byte through the files', () async {
      final snapshot = await persisted(params, batchSize: 2, focused: focused);

      final restored = await ReplicationTaskGenerationSnapshot.decode(
        snapshot,
        store,
      );
      expect(restored.sourceImage, params.sourceImage);
      expect(restored.maskImage, params.maskImage);
      expect(restored.vibeReferencesV4[0].rawImageData, _bytes(70000, 3));
      expect(restored.vibeReferencesV4[0].vibeEncoding, '');
      expect(restored.vibeReferencesV4[1].vibeEncoding, vibeEncoding);
      expect(restored.vibeReferencesV4[1].enabled, isFalse);
      expect(restored.vibeReferencesV4[2].vibeEncoding, 'QUJD\n');
      expect(restored.preciseReferences.single.image, _bytes(80000, 4));
      expect(restored.isOutpaint, isTrue);
      expect(restored.upscaledEnhance, isTrue);
    });

    test('clones and edits text without touching image files', () async {
      final snapshot = await persisted(params, batchSize: 2, focused: focused);
      final writes = files.writes;

      expect(
        jsonEncode(ReplicationTaskGenerationSnapshot.clone(snapshot)),
        jsonEncode(snapshot),
      );
      final edited = ReplicationTaskGenerationSnapshot.withTaskText(
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
      expect(files.writes, writes);
    });

    test(
      'interning hashes identical bytes once and writes them once',
      () async {
        final first = await ReplicationTaskGenerationSnapshot.encode(params);
        final second = await ReplicationTaskGenerationSnapshot.encode(params);
        final copy = await ReplicationTaskGenerationSnapshot.encode(
          params.copyWith(sourceImage: Uint8List.fromList(params.sourceImage!)),
        );

        final interned = await ReplicationTaskGenerationSnapshot.intern([
          first,
          null,
          second,
          copy,
        ], store);
        interned.release();

        expect(files.writes, 6);
        expect(interned.snapshots[1], isNull);
        expect(
          jsonEncode(interned.snapshots[0]),
          jsonEncode(interned.snapshots[2]),
        );
        expect(
          jsonEncode(interned.snapshots[0]),
          jsonEncode(interned.snapshots[3]),
        );
      },
    );

    test('pending snapshots never serialize', () async {
      final pending = await ReplicationTaskGenerationSnapshot.encode(params);

      expect(ReplicationTaskGenerationSnapshot.isPending(pending), isTrue);
      expect(
        () => jsonEncode(pending),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(
        () => ReplicationTaskGenerationSnapshot.checkPersistable([pending]),
        throwsStateError,
      );
      final interned = await ReplicationTaskGenerationSnapshot.intern([
        pending,
      ], store);
      interned.release();
      final stored = interned.snapshots.single!;
      expect(ReplicationTaskGenerationSnapshot.isPending(stored), isFalse);
      ReplicationTaskGenerationSnapshot.checkPersistable([stored, null]);
    });

    test('missing or corrupt image files fail as FormatException', () async {
      final snapshot = await persisted(params);
      final sourcePath = files.files.keys.firstWhere(
        (path) => path.endsWith(sha256.convert(params.sourceImage!).toString()),
      );

      files.files[sourcePath] = _bytes(params.sourceImage!.length, 99);
      await expectLater(
        ReplicationTaskGenerationSnapshot.decode(snapshot, store),
        throwsA(isA<QueueBlobCorruptException>()),
      );

      files.files.remove(sourcePath);
      await expectLater(
        ReplicationTaskGenerationSnapshot.decode(snapshot, store),
        throwsA(isA<QueueBlobMissingException>()),
      );
    });

    test('describes the snapshot from the index alone', () async {
      final snapshot = await persisted(params, batchSize: 2);
      files.files.clear();

      expect(ReplicationTaskGenerationSnapshot.describe(snapshot), {
        'schema_version': 2,
        'index_valid': true,
        'images_verified': false,
        'action': 'infill',
        'model': params.model,
        'width': params.width,
        'height': params.height,
        'steps': params.effectiveSteps,
        'sampler': params.effectiveSampler,
        'scale': params.scale,
        'seed': 42,
        'has_source_image': true,
        'has_mask_image': true,
        'vibe_reference_count': 3,
        'precise_reference_count': 1,
        'character_count': 1,
      });
      expect(
        ReplicationTaskGenerationSnapshot.describe({'schemaVersion': 1}),
        containsPair('index_valid', false),
      );
    });

    test('rejects inline base64 and malformed references', () async {
      final valid = await persisted(params);
      final inline = Map<String, dynamic>.of(valid)
        ..['sourceImage'] = base64Encode(params.sourceImage!);
      final malformed = Map<String, dynamic>.of(valid)
        ..['maskImage'] = {'sha256': 'x', 'length': 1};

      for (final snapshot in [inline, malformed]) {
        await expectLater(
          ReplicationTaskGenerationSnapshot.decode(snapshot, store),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Invalid queued image reference',
            ),
          ),
        );
      }
    });

    test('the stored shape keeps 4.3.1 decoders failing safely', () async {
      final snapshot = await persisted(params, batchSize: 2, focused: focused);
      final textOnly = await persisted(const ImageParams(prompt: 'text only'));

      // 不带图片的快照同样写成新版本，旧版本一律按无效快照处理
      expect(textOnly['schemaVersion'], snapshot['schemaVersion']);
      expect(() => _legacyDecodeGuard(textOnly), throwsFormatException);

      // 4.3.1 只认顶层 schemaVersion == 1；图片槽位若是字符串会被当作 base64 读取
      expect(snapshot['schemaVersion'], isA<int>());
      expect(snapshot['schemaVersion'], isNot(1));
      expect(snapshot['params'], isA<Map>());
      for (final slot in [
        snapshot['sourceImage'],
        snapshot['maskImage'],
        for (final item in snapshot['vibeReferences'] as List) ...[
          (item as Map)['rawImageData'],
          item['vibeEncoding'],
        ],
        for (final item in snapshot['preciseReferences'] as List)
          (item as Map)['image'],
      ]) {
        expect(slot, anyOf(isNull, isA<Map>()));
      }
      expect(() => _legacyDecodeGuard(snapshot), throwsFormatException);
      expect(
        () => _legacyDecodeGuard(
          Map<String, dynamic>.of(snapshot)..['schemaVersion'] = 1,
        ),
        throwsFormatException,
      );
    });
  });
}

/// 4.3.1 解码器在读取图片前的检查，原样摘录。
void _legacyDecodeGuard(Map<String, dynamic> snapshot) {
  if (snapshot['schemaVersion'] != 1 || snapshot['params'] is! Map) {
    throw const FormatException('Unsupported queue generation snapshot');
  }
  Object? bytes(Object? encoded) {
    if (encoded == null) return null;
    if (encoded is! String) throw const FormatException('Invalid image data');
    return base64Decode(encoded);
  }

  bytes(snapshot['sourceImage']);
  bytes(snapshot['maskImage']);
}

Uint8List _bytes(int length, int seed) => Uint8List.fromList([
  for (var index = 0; index < length; index++) (index * 31 + seed) & 0xff,
]);

Map<String, dynamic> _ref(Uint8List bytes) => {
  'sha256': sha256.convert(bytes).toString(),
  'length': bytes.length,
};

// 持久化格式的独立描述，键序与取值都必须与写入的索引一致
Map<String, dynamic> _persistedFormat(ImageParams params) => {
  'schemaVersion': 2,
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
  'sourceImage': _ref(params.sourceImage!),
  'maskImage': _ref(params.maskImage!),
  'vibeReferences': [
    for (final reference in params.vibeReferencesV4)
      {
        'value': {
          ...reference.toJson(),
          if (reference.vibeEncoding.isNotEmpty) 'vibeEncoding': '',
        },
        if (reference.rawImageData != null)
          'rawImageData': _ref(reference.rawImageData!),
        if (reference.vibeEncoding.isNotEmpty)
          'vibeEncoding': _ref(utf8.encode(reference.vibeEncoding)),
      },
  ],
  'preciseReferences': [
    for (final reference in params.preciseReferences)
      {
        'image': _ref(reference.image),
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
