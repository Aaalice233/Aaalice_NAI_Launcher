import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';

const String alphaSmall = 'alpha_small.png';
const String betaLarge = 'beta_large.png';
const String alphaMedium = 'alpha_medium.png';
const String plainNoMetadata = 'plain_no_metadata.png';
const String legacyPendingSize = 'legacy_pending_size.png';
const String neverIndexed = 'never_indexed.png';

void main() {
  group('GalleryFilterService criteria coverage', () {
    late Directory tempDir;
    late GalleryDataSource dataSource;
    late List<File> allFiles;

    Future<List<String>> matchNames(FilterCriteria criteria) async {
      final service = GalleryFilterService(dataSource);
      final result = await service.applyFilters(allFiles, criteria);
      return result.files.map((file) => p.basename(file.path)).toList()..sort();
    }

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppLogger.initialize(isTestEnvironment: true);

      tempDir = Directory.systemTemp.createTempSync('gallery_filter_criteria_');
      await ConnectionPoolHolder.initialize(
        dbPath: p.join(tempDir.path, 'criteria_coverage.db'),
        maxConnections: 2,
      );

      dataSource = GalleryDataSource();
      await dataSource.initialize();

      Future<File> writeFile(String name, DateTime modifiedAt) async {
        final file = File(p.join(tempDir.path, name));
        await file.writeAsBytes(<int>[137, 80, 78, 71]);
        await file.setLastModified(modifiedAt);
        return file;
      }

      Future<File> seedImage({
        required String name,
        required DateTime modifiedAt,
        required int fileSize,
        int? width,
        int? height,
        NaiImageMetadata? metadata,
        bool favorite = false,
      }) async {
        final file = await writeFile(name, modifiedAt);
        final imageId = await dataSource.upsertImage(
          filePath: file.path,
          fileName: name,
          fileSize: fileSize,
          width: width,
          height: height,
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
          resolutionKey: width != null && height != null
              ? '${width}x$height'
              : null,
          metadataStatus: metadata == null
              ? MetadataStatus.none
              : MetadataStatus.success,
        );
        if (metadata != null) {
          await dataSource.upsertMetadata(imageId, metadata);
        }
        if (favorite) {
          await dataSource.toggleFavorite(imageId);
        }
        return file;
      }

      final files = <File>[
        await seedImage(
          name: alphaSmall,
          modifiedAt: DateTime(2026, 1, 10, 12),
          fileSize: 1000,
          width: 256,
          height: 256,
          favorite: true,
          metadata: const NaiImageMetadata(
            prompt: 'alpha scene, blue eyes',
            negativePrompt: '',
            seed: 1,
            sampler: 'k_euler',
            steps: 20,
            scale: 5.0,
            width: 256,
            height: 256,
            model: 'nai-diffusion-3',
          ),
        ),
        await seedImage(
          name: betaLarge,
          modifiedAt: DateTime(2026, 2, 10, 12),
          fileSize: 50000,
          width: 1024,
          height: 1536,
          metadata: const NaiImageMetadata(
            prompt: 'beta scene, blonde hair',
            negativePrompt: '',
            seed: 2,
            sampler: 'k_dpmpp_2m',
            steps: 28,
            scale: 6.5,
            width: 1024,
            height: 1536,
            model: 'nai-diffusion-4-5-full',
          ),
        ),
        await seedImage(
          name: alphaMedium,
          modifiedAt: DateTime(2026, 3, 10, 12),
          fileSize: 20000,
          width: 832,
          height: 1216,
          metadata: const NaiImageMetadata(
            prompt: 'alpha scene, blonde hair',
            negativePrompt: '',
            seed: 3,
            sampler: 'k_euler_ancestral',
            steps: 23,
            scale: 5.5,
            width: 832,
            height: 1216,
            model: 'nai-diffusion-4-5-full',
          ),
        ),
        await seedImage(
          name: plainNoMetadata,
          modifiedAt: DateTime(2026, 4, 10, 12),
          fileSize: 3000,
        ),
        // Image row indexed before its size was known; metadata carries it.
        await seedImage(
          name: legacyPendingSize,
          modifiedAt: DateTime(2026, 5, 10, 12),
          fileSize: 8000,
          metadata: const NaiImageMetadata(
            prompt: 'legacy artwork',
            negativePrompt: '',
            seed: 4,
            sampler: 'legacy_sampler',
            steps: 40,
            scale: 5.0,
            width: 320,
            height: 320,
            model: 'legacy-diffusion',
          ),
        ),
        await writeFile(neverIndexed, DateTime(2026, 1, 10, 12)),
      ];

      allFiles = List<File>.unmodifiable(files);
    });

    tearDownAll(() async {
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('without a search query', () {
      test('model filter matches indexed metadata', () async {
        expect(
          await matchNames(
            const FilterCriteria(filterModel: 'nai-diffusion-4-5'),
          ),
          [alphaMedium, betaLarge],
        );
        expect(
          await matchNames(
            const FilterCriteria(filterModel: 'nai-diffusion-3'),
          ),
          [alphaSmall],
        );
      });

      test('sampler filter matches by containment', () async {
        expect(
          await matchNames(const FilterCriteria(filterSampler: 'k_euler')),
          [alphaMedium, alphaSmall],
        );
        expect(
          await matchNames(const FilterCriteria(filterSampler: 'k_dpmpp')),
          [betaLarge],
        );
      });

      test('steps range filter narrows to the matching image', () async {
        expect(
          await matchNames(
            const FilterCriteria(filterMinSteps: 21, filterMaxSteps: 25),
          ),
          [alphaMedium],
        );
      });

      test('cfg range filter narrows to the matching image', () async {
        expect(await matchNames(const FilterCriteria(filterMinCfg: 6.0)), [
          betaLarge,
        ]);
        expect(await matchNames(const FilterCriteria(filterMaxCfg: 5.2)), [
          alphaSmall,
          legacyPendingSize,
        ]);
      });

      test('resolution filter matches width by height', () async {
        expect(
          await matchNames(const FilterCriteria(filterResolution: '832x1216')),
          [alphaMedium],
        );
        expect(
          await matchNames(const FilterCriteria(filterResolution: '1024x1536')),
          [betaLarge],
        );
      });

      test(
        'resolution filter falls back to containment for free text',
        () async {
          expect(
            await matchNames(const FilterCriteria(filterResolution: '1216')),
            [alphaMedium],
          );
        },
      );

      test('dimension filters fall back to metadata size', () async {
        expect(await matchNames(const FilterCriteria(minWidth: 300)), [
          alphaMedium,
          betaLarge,
          legacyPendingSize,
        ]);
        expect(
          await matchNames(const FilterCriteria(filterResolution: '320x320')),
          [legacyPendingSize],
        );
      });

      test('dimension filters apply without a search query', () async {
        expect(await matchNames(const FilterCriteria(minWidth: 500)), [
          alphaMedium,
          betaLarge,
        ]);
        expect(await matchNames(const FilterCriteria(maxHeight: 300)), [
          alphaSmall,
        ]);
      });

      test('file size filters apply without a search query', () async {
        expect(await matchNames(const FilterCriteria(minFileSize: 10000)), [
          alphaMedium,
          betaLarge,
        ]);
        expect(await matchNames(const FilterCriteria(maxFileSize: 5000)), [
          alphaSmall,
          plainNoMetadata,
        ]);
      });

      test('metadata status filter applies without a search query', () async {
        expect(
          await matchNames(const FilterCriteria(metadataStatuses: ['none'])),
          [plainNoMetadata],
        );
        expect(
          await matchNames(const FilterCriteria(metadataStatuses: ['success'])),
          [alphaMedium, alphaSmall, betaLarge, legacyPendingSize],
        );
      });

      test('favorites filter returns the favorited image', () async {
        expect(
          await matchNames(const FilterCriteria(showFavoritesOnly: true)),
          [alphaSmall],
        );
      });

      test('metadata conditions drop images without metadata', () async {
        expect(await matchNames(const FilterCriteria(filterMinSteps: 1)), [
          alphaMedium,
          alphaSmall,
          betaLarge,
          legacyPendingSize,
        ]);
      });

      test('index conditions drop files that are not indexed yet', () async {
        expect(await matchNames(const FilterCriteria(minFileSize: 1)), [
          alphaMedium,
          alphaSmall,
          betaLarge,
          legacyPendingSize,
          plainNoMetadata,
        ]);
      });

      test('date range keeps files that are not indexed yet', () async {
        expect(
          await matchNames(
            FilterCriteria(
              dateStart: DateTime(2026, 1, 1),
              dateEnd: DateTime(2026, 1, 31),
            ),
          ),
          [alphaSmall, neverIndexed],
        );
      });

      test(
        'date range combined with an index condition drops unindexed files',
        () async {
          expect(
            await matchNames(
              FilterCriteria(
                dateStart: DateTime(2026, 1, 1),
                dateEnd: DateTime(2026, 1, 31),
                minFileSize: 1,
              ),
            ),
            [alphaSmall],
          );
        },
      );
    });

    group('with a plain search query', () {
      test('search combines with dimension filters', () async {
        expect(
          await matchNames(
            const FilterCriteria(searchQuery: 'alpha', minWidth: 500),
          ),
          [alphaMedium],
        );
      });

      test('search combines with the model filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              searchQuery: 'alpha',
              filterModel: 'nai-diffusion-3',
            ),
          ),
          [alphaSmall],
        );
      });

      test('search combines with the steps filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(searchQuery: 'scene', filterMinSteps: 25),
          ),
          [betaLarge],
        );
      });

      test('search combines with the resolution filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              searchQuery: 'scene',
              filterResolution: '832x1216',
            ),
          ),
          [alphaMedium],
        );
      });
    });

    group('with a comma separated search query', () {
      test('segments are matched with AND', () async {
        expect(
          await matchNames(const FilterCriteria(searchQuery: 'scene,blonde')),
          [alphaMedium, betaLarge],
        );
      });

      test('segments combine with the sampler filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              searchQuery: 'scene,blonde',
              filterSampler: 'k_dpmpp',
            ),
          ),
          [betaLarge],
        );
      });

      test('segments combine with the resolution filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              searchQuery: 'scene,blonde',
              filterResolution: '832x1216',
            ),
          ),
          [alphaMedium],
        );
      });

      test('segments combine with the cfg filter', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              searchQuery: 'scene,blonde',
              filterMinCfg: 6.0,
            ),
          ),
          [betaLarge],
        );
      });
    });

    group('combined criteria', () {
      test('model, steps and resolution intersect', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              filterModel: 'nai-diffusion-4-5-full',
              filterMinSteps: 25,
              filterResolution: '1024x1536',
            ),
          ),
          [betaLarge],
        );
      });

      test('conflicting criteria return nothing', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              filterModel: 'nai-diffusion-3',
              filterResolution: '1024x1536',
            ),
          ),
          isEmpty,
        );
      });

      test('favorites intersect with metadata criteria', () async {
        expect(
          await matchNames(
            const FilterCriteria(
              showFavoritesOnly: true,
              filterSampler: 'k_euler',
            ),
          ),
          [alphaSmall],
        );
        expect(
          await matchNames(
            const FilterCriteria(
              showFavoritesOnly: true,
              filterSampler: 'k_dpmpp',
            ),
          ),
          isEmpty,
        );
      });
    });
  });
}
