import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test('toDisplayEntry strips heavy payload but preserves UI fields', () {
    final thumbnail = Uint8List.fromList([1, 2, 3]);
    final vibeThumbnail = Uint8List.fromList([4, 5, 6]);
    final preview = Uint8List.fromList([7, 8, 9]);
    final rawImage = Uint8List.fromList([10, 11, 12]);
    final createdAt = DateTime(2026, 4, 14, 12, 0, 0);
    final lastUsedAt = DateTime(2026, 4, 14, 12, 30, 0);

    final entry = VibeLibraryEntry(
      id: 'entry-1',
      name: 'spring vibe',
      vibeDisplayName: 'Spring Vibe',
      vibeEncoding: 'encoded-payload',
      vibeThumbnail: vibeThumbnail,
      rawImageData: rawImage,
      strength: 0.65,
      infoExtracted: 0.75,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      categoryId: 'cat-1',
      tags: const ['flower', 'bright'],
      isFavorite: true,
      usedCount: 12,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
      thumbnail: thumbnail,
      filePath: r'G:\AIdarw\vibes\spring.naiv4vibe',
      bundleId: 'bundle-1',
      bundledVibeNames: const ['a', 'b'],
      bundledVibePreviews: [preview],
      bundledVibeEncodings: const ['enc-1', 'enc-2'],
      bundledVibeStrengths: const [0.2, 0.8],
      bundledVibeInfoExtracted: const [0.3, 0.9],
      encodingModel: ImageModels.animeDiffusionV45Full,
      bundledVibeEncodingModels: const [
        ImageModels.animeDiffusionV4Full,
        ImageModels.animeDiffusionV45Full,
      ],
    );

    final display = entry.toDisplayEntry();

    expect(display.id, entry.id);
    expect(display.name, entry.name);
    expect(display.vibeDisplayName, entry.vibeDisplayName);
    expect(display.tags, entry.tags);
    expect(display.thumbnail, isNull);
    expect(display.vibeThumbnail, isNull);
    expect(display.filePath, entry.filePath);
    expect(display.isFavorite, isTrue);
    expect(display.usedCount, entry.usedCount);
    expect(display.lastUsedAt, lastUsedAt);
    expect(display.bundledVibeNames, entry.bundledVibeNames);
    expect(display.encodingModel, entry.encodingModel);

    expect(display.vibeEncoding, isEmpty);
    expect(display.rawImageData, isNull);
    expect(display.bundledVibePreviews, isNull);
    expect(display.bundledVibeEncodings, isNull);
    expect(display.bundledVibeStrengths, isNull);
    expect(display.bundledVibeInfoExtracted, isNull);
    expect(display.bundledVibeEncodingModels, isNull);
  });

  test('VibeReference conversion preserves the encoding model', () {
    const reference = VibeReference(
      displayName: 'Model-aware Vibe',
      vibeEncoding: 'encoded',
      encodingModel: ImageModels.animeDiffusionV45Curated,
      sourceType: VibeSourceType.naiv4vibe,
    );

    final entry = VibeLibraryEntry.fromVibeReference(
      name: 'Model-aware Vibe',
      vibeData: reference,
    );

    expect(entry.encodingModel, ImageModels.animeDiffusionV45Curated);
    expect(
      entry.toVibeReference().encodingModel,
      ImageModels.animeDiffusionV45Curated,
    );
  });

  test('merge fills a missing model only for the matching file encoding', () {
    const fileVibe = VibeReference(
      displayName: 'Vibe',
      vibeEncoding: 'encoding',
      sourceType: VibeSourceType.naiv4vibe,
    );
    final entry = VibeLibraryEntry.fromVibeReference(
      name: 'Vibe',
      vibeData: fileVibe.copyWith(
        encodingModel: ImageModels.animeDiffusionV45Full,
      ),
    );

    expect(
      entry.mergeFileVibeData(fileVibe).encodingModel,
      entry.encodingModel,
    );
    expect(
      entry
          .mergeFileVibeData(fileVibe.copyWith(vibeEncoding: 'changed'))
          .encodingModel,
      isNull,
    );
    final fileWithModel = fileVibe.copyWith(
      encodingModel: ImageModels.animeDiffusionV4Full,
    );
    expect(
      entry.mergeFileVibeData(fileWithModel).encodingModel,
      fileWithModel.encodingModel,
    );
  });

  test('merge keeps the model declared by a file without an encoding', () {
    final fileVibe = VibeReference(
      displayName: 'Vibe',
      vibeEncoding: '',
      rawImageData: Uint8List.fromList([1, 2, 3]),
      encodingModel: ImageModels.animeDiffusionV4Full,
      sourceType: VibeSourceType.rawImage,
    );
    final entry = VibeLibraryEntry.fromVibeReference(
      name: 'Vibe',
      vibeData: fileVibe.copyWith(
        encodingModel: ImageModels.animeDiffusionV45Full,
      ),
    );

    expect(
      entry.mergeFileVibeData(fileVibe).encodingModel,
      fileVibe.encodingModel,
    );
  });

  test('sortedByName 不区分大小写，名称为空时按 vibeDisplayName 参与排序', () {
    final entries = [
      _namedEntry('c', name: '', vibeDisplayName: 'Charlie'),
      _namedEntry('a', name: 'alpha', vibeDisplayName: 'Zulu'),
      _namedEntry('b', name: '', vibeDisplayName: 'bravo'),
    ];

    expect(entries.sortedByName().map((entry) => entry.id), ['a', 'b', 'c']);
    expect(
      entries.map((entry) => entry.id),
      ['c', 'a', 'b'],
      reason: '排序不能改动原列表',
    );
  });

  group('hasSameStoredContent', () {
    VibeLibraryEntry full() => VibeLibraryEntry(
      id: 'entry',
      name: 'name',
      vibeDisplayName: 'display',
      vibeEncoding: 'encoding',
      vibeThumbnail: Uint8List.fromList(List.generate(19, (i) => i)),
      rawImageData: Uint8List.fromList(List.generate(33, (i) => i * 3)),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibebundle.index,
      categoryId: 'category',
      tags: ['a', 'b'],
      isFavorite: true,
      usedCount: 4,
      lastUsedAt: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 9, 1),
      thumbnail: Uint8List.fromList(List.generate(17, (i) => 255 - i)),
      filePath: 'C:/vibes/entry.naiv4vibebundle',
      bundleId: 'bundle',
      bundledVibeNames: ['first', 'second'],
      bundledVibePreviews: [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList(List.generate(24, (i) => i)),
      ],
      bundledVibeEncodings: ['e1', 'e2'],
      bundledVibeStrengths: [0.1, 0.2],
      bundledVibeInfoExtracted: [0.3, 0.4],
      encodingModel: 'nai-diffusion-4-full',
      bundledVibeEncodingModels: ['nai-diffusion-4-full', null],
    );

    final mutations = <String, VibeLibraryEntry Function(VibeLibraryEntry)>{
      'id': (e) => e.copyWith(id: 'other'),
      'name': (e) => e.copyWith(name: 'other'),
      'vibeDisplayName': (e) => e.copyWith(vibeDisplayName: 'other'),
      'vibeEncoding': (e) => e.copyWith(vibeEncoding: 'other'),
      'vibeThumbnail': (e) => e.copyWith(
        vibeThumbnail: Uint8List.fromList([...e.vibeThumbnail!]..[18] = 0),
      ),
      'rawImageData': (e) => e.copyWith(
        rawImageData: Uint8List.fromList([...e.rawImageData!]..[1] = 0),
      ),
      'strength': (e) => e.copyWith(strength: 0.61),
      'infoExtracted': (e) => e.copyWith(infoExtracted: 0.71),
      'sourceTypeIndex': (e) =>
          e.copyWith(sourceTypeIndex: VibeSourceType.naiv4vibe.index),
      'categoryId': (e) => e.copyWith(categoryId: null),
      'tags': (e) => e.copyWith(tags: ['a']),
      'isFavorite': (e) => e.copyWith(isFavorite: false),
      'usedCount': (e) => e.copyWith(usedCount: 5),
      'lastUsedAt': (e) => e.copyWith(lastUsedAt: DateTime(2026, 10, 2)),
      'createdAt': (e) => e.copyWith(createdAt: DateTime(2026, 9, 2)),
      'thumbnail': (e) => e.copyWith(thumbnail: null),
      'filePath': (e) => e.copyWith(filePath: 'C:/vibes/moved.naiv4vibebundle'),
      'bundleId': (e) => e.copyWith(bundleId: 'other'),
      'bundledVibeNames': (e) => e.copyWith(bundledVibeNames: ['first']),
      'bundledVibePreviews': (e) => e.copyWith(
        bundledVibePreviews: [
          e.bundledVibePreviews!.first,
          Uint8List.fromList(List.generate(24, (i) => i == 23 ? 0 : i)),
        ],
      ),
      'bundledVibeEncodings': (e) =>
          e.copyWith(bundledVibeEncodings: ['e1', 'changed']),
      'bundledVibeStrengths': (e) =>
          e.copyWith(bundledVibeStrengths: [0.1, 0.25]),
      'bundledVibeInfoExtracted': (e) =>
          e.copyWith(bundledVibeInfoExtracted: [0.3, 0.45]),
      'encodingModel': (e) => e.copyWith(encodingModel: null),
      'bundledVibeEncodingModels': (e) => e.copyWith(
        bundledVibeEncodingModels: ['nai-diffusion-4-full', 'other'],
      ),
    };

    test('equal content in distinct instances counts as unchanged', () {
      final left = full();
      final right = full();

      expect(identical(left.rawImageData, right.rawImageData), isFalse);
      expect(left.hasSameStoredContent(right), isTrue);
      expect(left.hasSameStoredContent(left.copyWith()), isTrue);
    });

    for (final MapEntry(key: field, value: mutate) in mutations.entries) {
      test('a change to $field counts as changed', () {
        final original = full();
        final changed = mutate(full());

        expect(original.hasSameStoredContent(changed), isFalse);
        expect(changed.hasSameStoredContent(original), isFalse);
      });
    }

    test('every persisted field is covered', () {
      final source = File(
        'lib/data/models/vibe/vibe_library_entry.dart',
      ).readAsStringSync();
      final fieldCount = RegExp(r'@HiveField\(').allMatches(source).length;

      // 新增持久化字段时必须同步加进比较，否则刷新会漏写它的变化
      expect(mutations, hasLength(fieldCount));
    });
  });
}

VibeLibraryEntry _namedEntry(
  String id, {
  required String name,
  required String vibeDisplayName,
}) {
  return VibeLibraryEntry(
    id: id,
    name: name,
    vibeDisplayName: vibeDisplayName,
    vibeEncoding: 'encoded-$id',
    createdAt: DateTime(2026, 4, 14),
  );
}
