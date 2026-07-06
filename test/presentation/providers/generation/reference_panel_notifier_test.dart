import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/generation/reference_panel_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'reference_panel_notifier_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      try {
        await hiveTempDir.delete(recursive: true);
      } on PathAccessException {
        // Windows 测试环境偶尔会延迟释放 Hive 句柄，不影响断言结果。
      }
    }
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.historyBox).clear();
  });

  test('encodeVibesNow 编码后会保留原图数据以便后续重新编码', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(
          _FakeEnhancementApiService(),
        ),
        vibeLibraryStorageServiceProvider.overrideWithValue(
          _FakeVibeLibraryStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(referencePanelNotifierProvider.notifier);
    final raw = Uint8List.fromList(const [1, 2, 3, 4]);

    final encoded = await notifier.encodeVibesNow(
      [
        VibeReference(
          displayName: 'raw-vibe',
          vibeEncoding: '',
          rawImageData: raw,
          thumbnail: raw,
          strength: -0.4,
          infoExtracted: 0.2,
          sourceType: VibeSourceType.rawImage,
        ),
      ],
      model: 'nai-diffusion-4-full',
    );

    expect(encoded, isNotNull);
    expect(encoded!.single.vibeEncoding, 'nai-diffusion-4-full|0.2|1');
    expect(encoded.single.rawImageData, raw);
  });

  test('addLibraryVibe 会优先使用真实文件条目的参数和原图数据', () async {
    SharedPreferences.setMockInitialValues({});

    final staleEntry = VibeLibraryEntry(
      id: 'entry-1',
      name: 'Library Vibe',
      vibeDisplayName: 'Library Vibe',
      vibeEncoding: 'stale-encoding',
      vibeThumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15),
    );
    final actualEntry = staleEntry.copyWith(
      vibeEncoding: 'actual-encoding',
      rawImageData: Uint8List.fromList(const [9, 8, 7, 6]),
      infoExtracted: 0.25,
      strength: -0.35,
    );

    final container = ProviderContainer(
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(
          _FakeVibeLibraryStorageService(actualEntry: actualEntry),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(referencePanelNotifierProvider.notifier);
    final added = await notifier.addLibraryVibe(staleEntry);

    expect(added, isTrue);
    final vibe =
        container.read(generationParamsNotifierProvider).vibeReferencesV4.single;
    expect(vibe.vibeEncoding, 'actual-encoding');
    expect(vibe.rawImageData, actualEntry.rawImageData);
    expect(vibe.infoExtracted, 0.25);
    expect(vibe.strength, -0.35);
  });
}

class _FakeEnhancementApiService extends NAIImageEnhancementApiService {
  _FakeEnhancementApiService() : super(Dio());

  int callCount = 0;

  @override
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    callCount++;
    return '$model|$informationExtracted|$callCount';
  }
}

class _FakeVibeLibraryStorageService extends VibeLibraryStorageService {
  _FakeVibeLibraryStorageService({this.actualEntry});

  final VibeLibraryEntry? actualEntry;

  @override
  Future<List<VibeLibraryEntry>> getRecentEntries({int limit = 20}) async {
    return [];
  }

  @override
  Future<VibeLibraryEntry?> getEntry(String id) async {
    if (actualEntry != null && actualEntry!.id == id) {
      return actualEntry;
    }
    return null;
  }

  @override
  Future<VibeLibraryEntry?> incrementUsedCount(String id) async {
    return actualEntry;
  }
}
