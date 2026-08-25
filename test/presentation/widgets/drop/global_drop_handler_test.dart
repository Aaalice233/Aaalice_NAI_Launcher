import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/drop/global_drop_handler.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/webp_metadata_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_global_drop_hive_',
    );
    final appSupportDir = await Directory(
      '${hiveTempDir.path}${Platform.pathSeparator}app_support',
    ).create();
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      appSupportDir.path,
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  group('GlobalDropHandler', () {
    late ProviderContainer container;

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('plain PNG has no importable dropped-image metadata', () async {
      final metadata = await detectImportableDroppedImageMetadata(
        'clipboard_image.png',
        Uint8List.fromList(_transparentPngBytes),
      );

      expect(metadata, isNull);
    });

    test('ordinary PNG text is not reported as a parse failure', () async {
      final bytes = UnifiedMetadataParser.embedTextChunkOnly(
        Uint8List.fromList(_transparentPngBytes),
        'Software',
        'Example image editor',
      );

      final detection = await detectDroppedImageMetadata('edited.png', bytes);

      expect(detection.metadata, isNull);
      expect(detection.parseError, isNull);
    });

    test('malformed generation metadata reports a parse failure', () async {
      final bytes = UnifiedMetadataParser.embedTextChunkOnly(
        Uint8List.fromList(_transparentPngBytes),
        'Comment',
        'unparseable payload',
      );

      final detection = await detectDroppedImageMetadata(
        'broken_metadata.png',
        bytes,
      );

      expect(detection.metadata, isNull);
      expect(detection.parseError, contains('from 1 fields'));
    });

    test(
      'clipboard WebP bytes without a file path use shared metadata parsing',
      () async {
        final metadata = await detectImportableDroppedImageMetadata(
          'clipboard_image',
          buildNovelAiWebpFixture(
            comment: const {
              'prompt': 'clipboard webp',
              'uc': '',
              'seed': 11,
              'steps': 28,
              'scale': 5.0,
              'sampler': 'k_euler',
            },
          ),
        );

        expect(metadata?.prompt, 'clipboard webp');
      },
    );

    test('dropped uppercase WebP uses shared metadata parsing', () async {
      final metadata = await detectImportableDroppedImageMetadata(
        'dropped_image.WEBP',
        buildNovelAiWebpFixture(
          comment: const {
            'prompt': 'dropped webp',
            'uc': '',
            'seed': 12,
            'steps': 28,
            'scale': 5.0,
            'sampler': 'k_euler',
          },
        ),
      );

      expect(metadata?.prompt, 'dropped webp');
    });

    test('only gallery internal drags bypass the global drop handler', () {
      expect(
        isGalleryInternalDragLocalData({'source': 'gallery_internal'}),
        isTrue,
      );
      expect(
        isGalleryInternalDragLocalData({'source': 'history_internal'}),
        isFalse,
      );
      expect(
        isGalleryInternalDragLocalData({'source': 'other_internal'}),
        isFalse,
      );
      expect(isGalleryInternalDragLocalData(null), isFalse);
    });

    test(
      'dropped character reference appends to existing precise references',
      () async {
        final notifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        await notifier.addPreciseReferenceFromImage(
          Uint8List.fromList(_transparentPngBytes),
          type: PreciseRefType.character,
          strength: 0.8,
          fidelity: 0.9,
        );
        final existingReference = container
            .read(generationParamsNotifierProvider)
            .preciseReferences
            .single;

        await appendDroppedCharacterReference(
          notifier: notifier,
          image: Uint8List.fromList(_transparentPngBytes),
        );

        final references = container
            .read(generationParamsNotifierProvider)
            .preciseReferences;
        expect(references, hasLength(2));
        expect(references.first, same(existingReference));
        expect(references.last.type, PreciseRefType.characterAndStyle);
        expect(references.last.strength, 1.0);
        expect(references.last.fidelity, 1.0);
      },
    );

    test(
      'dropped character reference returns after staging original image',
      () async {
        final notifier = container.read(
          generationParamsNotifierProvider.notifier,
        );
        final image = Uint8List.fromList(_transparentPngBytes);

        await appendDroppedCharacterReference(notifier: notifier, image: image);

        final references = container
            .read(generationParamsNotifierProvider)
            .preciseReferences;
        expect(references, hasLength(1));
        expect(identical(references.single.image, image), isTrue);
      },
    );
  });
}

const _transparentPngBytes = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.appSupportPath);

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
