import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_scan_coordinator.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/gallery_database_sandbox.dart';

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_startup_admission_');

  test('启动只统计准入路径并保留旧索引、收藏和相簿成员', () async {
    final root = p.join(sandbox.root.path, 'gallery');
    final dataSource = sandbox.dataSource;
    final repository = LocalGalleryRepository(dataSource: dataSource);
    final coordinator = GalleryScanCoordinator(
      dataSource: dataSource,
      repository: repository,
    );
    Future<int> index(String path, MetadataStatus status) async {
      final file = await File(path).create(recursive: true);
      return dataSource.upsertImage(
        filePath: file.path,
        fileName: p.basename(file.path),
        fileSize: 0,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        metadataStatus: status,
      );
    }

    final hiddenId = await index(
      p.join(root, '.private', 'old.png'),
      MetadataStatus.none,
    );
    expect(await dataSource.toggleFavorite(hiddenId), isTrue);
    final albumId = await dataSource.albums.createAlbum(name: '归档');
    expect(await dataSource.albums.addImagesToAlbum(albumId, [hiddenId]), 1);

    Future<Map<String, List<Map<String, Object?>>>> hiddenRows() async {
      final pool = ConnectionPoolHolder.instance;
      final db = await pool.acquire();
      try {
        return {
          GalleryTables.images: await db.query(
            GalleryTables.images,
            where: 'id = ?',
            whereArgs: [hiddenId],
          ),
          for (final table in [
            GalleryTables.favorites,
            GalleryTables.albumImages,
          ])
            table: await db.query(
              table,
              where: 'image_id = ?',
              whereArgs: [hiddenId],
            ),
        };
      } finally {
        await pool.release(db);
      }
    }

    final before = await hiddenRows();
    expect(before.values.map((rows) => rows.length), [1, 1, 1]);
    Future<GalleryStartupIndexAction> decide() async =>
        coordinator.startupIndexAction(
          root,
          (await repository.findGalleryFiles(root)).length,
        );

    expect(await decide(), GalleryStartupIndexAction.none);
    await index(p.join(root, 'visible.png'), MetadataStatus.success);
    expect(await decide(), GalleryStartupIndexAction.none);
    await File(p.join(root, 'new.png')).create();
    expect(await decide(), GalleryStartupIndexAction.fullScan);
    expect(await hiddenRows(), before);
  });

  test('索引数与文件数相等且元数据已处理时不逐行查询', () async {
    final dataSource = _MockGalleryDataSource();
    final coordinator = GalleryScanCoordinator(
      dataSource: dataSource,
      repository: LocalGalleryRepository(dataSource: dataSource),
    );
    const fileCount = 60000;
    registerFallbackValue((String path) => true);
    when(() => dataSource.countImages()).thenAnswer((_) async => fileCount);
    when(
      () => dataSource.countImagesByMetadataStatus(),
    ).thenAnswer((_) async => {'success': fileCount, 'none': 0});
    when(
      () => dataSource.countImagesForPaths(any()),
    ).thenAnswer((_) async => (total: fileCount, unparsed: 0));

    expect(
      await coordinator.startupIndexAction(sandbox.root.path, fileCount),
      GalleryStartupIndexAction.none,
    );
    verifyNever(() => dataSource.countImagesForPaths(any()));
    verify(() => dataSource.countImages()).called(1);
    verify(() => dataSource.countImagesByMetadataStatus()).called(1);
  });
}

class _MockGalleryDataSource extends Mock implements GalleryDataSource {}
