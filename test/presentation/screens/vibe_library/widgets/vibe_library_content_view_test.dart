import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_library_content_view.dart';

void main() {
  test('首屏网格缓存范围应收敛，避免额外预构建过多卡片', () {
    expect(computeVibeGridCacheExtent(200), 300);
    expect(computeVibeGridCacheExtent(160), 240);
  });

  test('打开详情前应优先回读真实条目参数，而不是继续使用列表旧快照', () async {
    final staleEntry = _buildEntry(strength: 0.6, infoExtracted: 0.7);
    final actualEntry = _buildEntry(strength: 0.18, infoExtracted: 0.3);
    final resolved = await resolveVibeDetailEntryForOpen(
      _DetailEntryStorage(actualEntry),
      staleEntry,
    );

    expect(resolved.strength, 0.18);
    expect(resolved.infoExtracted, 0.3);
  });

  test('真实条目不可用时，打开详情仍回退使用当前列表条目', () async {
    final staleEntry = _buildEntry(strength: 0.6, infoExtracted: 0.7);
    final resolved = await resolveVibeDetailEntryForOpen(
      _DetailEntryStorage(null),
      staleEntry,
    );

    expect(resolved, same(staleEntry));
  });

  test('发送 bundle 到生成页时默认保留每个子 Vibe 自己的参数', () {
    const vibes = [
      VibeReference(
        displayName: 'first',
        vibeEncoding: 'encoding-1',
        strength: 0.15,
        infoExtracted: 0.25,
      ),
      VibeReference(
        displayName: 'second',
        vibeEncoding: 'encoding-2',
        strength: -0.35,
        infoExtracted: 0.85,
      ),
    ];

    final result = buildBundleVibesForGeneration(
      vibes,
      bundleSource: 'bundle-a',
    );

    expect(result.map((v) => v.strength), [0.15, -0.35]);
    expect(result.map((v) => v.infoExtracted), [0.25, 0.85]);
    expect(result.map((v) => v.bundleSource), ['bundle-a', 'bundle-a']);
  });

  test('明确整体覆盖时才把同一套参数应用到 bundle 子 Vibe', () {
    const vibes = [
      VibeReference(
        displayName: 'first',
        vibeEncoding: 'encoding-1',
        strength: 0.15,
        infoExtracted: 0.25,
      ),
      VibeReference(
        displayName: 'second',
        vibeEncoding: 'encoding-2',
        strength: -0.35,
        infoExtracted: 0.85,
      ),
    ];

    final result = buildBundleVibesForGeneration(
      vibes,
      bundleSource: 'bundle-a',
      strengthOverride: 0.6,
      infoExtractedOverride: 0.7,
    );

    expect(result.map((v) => v.strength), [0.6, 0.6]);
    expect(result.map((v) => v.infoExtracted), [0.7, 0.7]);
  });

  test('指定子项覆盖时只更新该 bundle 子 Vibe', () {
    const vibes = [
      VibeReference(
        displayName: 'first',
        vibeEncoding: 'encoding-1',
        strength: 0.15,
        infoExtracted: 0.25,
      ),
      VibeReference(
        displayName: 'second',
        vibeEncoding: 'encoding-2',
        strength: -0.35,
        infoExtracted: 0.85,
      ),
    ];

    final result = buildBundleVibesForGeneration(
      vibes,
      bundleSource: 'bundle-a',
      strengthOverride: 0.6,
      infoExtractedOverride: 0.7,
      overrideIndex: 1,
    );

    expect(result.map((v) => v.strength), [0.15, 0.6]);
    expect(result.map((v) => v.infoExtracted), [0.25, 0.7]);
  });
}

VibeLibraryEntry _buildEntry({
  required double strength,
  required double infoExtracted,
}) {
  final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);
  return VibeLibraryEntry(
    id: 'entry-1',
    name: 'Library Vibe',
    vibeDisplayName: 'Library Vibe',
    vibeEncoding: 'encoded-before',
    vibeThumbnail: imageBytes,
    rawImageData: imageBytes,
    strength: strength,
    infoExtracted: infoExtracted,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    createdAt: DateTime(2026, 4, 15),
  );
}

class _DetailEntryStorage extends VibeLibraryStorageService {
  _DetailEntryStorage(this.entry);

  final VibeLibraryEntry? entry;

  @override
  Future<VibeLibraryEntry?> getEntry(String id) async => entry;
}
