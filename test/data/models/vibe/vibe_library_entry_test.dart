import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

    expect(display.vibeEncoding, isEmpty);
    expect(display.rawImageData, isNull);
    expect(display.bundledVibePreviews, isNull);
    expect(display.bundledVibeEncodings, isNull);
    expect(display.bundledVibeStrengths, isNull);
    expect(display.bundledVibeInfoExtracted, isNull);
  });
}
