import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

/// 相簿数据访问层单元测试
///
/// 运行: flutter test test/core/database/datasources/gallery_album_repository_test.dart
void main() {
  late GalleryDataSource dataSource;
  late String testDbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
    final tempDir = Directory.systemTemp.createTempSync('gallery_album_test_');
    testDbPath = '${tempDir.path}/test_gallery.db';
  });

  tearDownAll(() async {
    await ConnectionPoolHolder.dispose();
    try {
      await Directory(testDbPath).parent.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    if (ConnectionPoolHolder.isInitialized) {
      await ConnectionPoolHolder.dispose();
    }
    try {
      final dbFile = File(testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
    } catch (_) {}

    await ConnectionPoolHolder.initialize(
      dbPath: testDbPath,
      maxConnections: 2,
    );
    dataSource = GalleryDataSource();
    await dataSource.initialize();
  });

  tearDown(() async {
    await dataSource.dispose();
    await ConnectionPoolHolder.dispose();
    try {
      final dbFile = File(testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
    } catch (_) {}
  });

  Future<int> seedImage(String path) async {
    final now = DateTime.now();
    return dataSource.upsertImage(
      filePath: path,
      fileName: path.split('/').last,
      fileSize: 1024,
      createdAt: now,
      modifiedAt: now,
    );
  }

  test(
    'createAlbum and getAlbums return tree order with subtree counts',
    () async {
      final rootId = await dataSource.albums.createAlbum(name: '角色');
      final childId = await dataSource.albums.createAlbum(
        name: '猫娘',
        parentId: rootId,
      );

      final rootImage = await seedImage('gallery/root.png');
      final childImage = await seedImage('gallery/child.png');
      await dataSource.albums.addImagesToAlbum(rootId, [rootImage]);
      await dataSource.albums.addImagesToAlbum(childId, [childImage]);

      final albums = await dataSource.albums.getAlbums();

      expect(albums.map((a) => a.name).toList(), ['角色', '猫娘']);
      final root = albums.first;
      final child = albums.last;
      // 父相簿计数含子相簿成员（去重）
      expect(root.imageCount, 2);
      expect(child.imageCount, 1);
    },
  );

  test('addImagesToAlbum is idempotent for existing members', () async {
    final albumId = await dataSource.albums.createAlbum(name: 'A');
    final imageId = await seedImage('gallery/a.png');

    final first = await dataSource.albums.addImagesToAlbum(albumId, [imageId]);
    final second = await dataSource.albums.addImagesToAlbum(albumId, [imageId]);

    expect(first, 1);
    expect(second, 0);

    final albums = await dataSource.albums.getAlbums();
    expect(albums.single.imageCount, 1);
  });

  test('removeImagesFromAlbum removes only requested members', () async {
    final albumId = await dataSource.albums.createAlbum(name: 'A');
    final imageA = await seedImage('gallery/a.png');
    final imageB = await seedImage('gallery/b.png');
    await dataSource.albums.addImagesToAlbum(albumId, [imageA, imageB]);

    final removed = await dataSource.albums.removeImagesFromAlbum(albumId, [
      imageA,
    ]);

    expect(removed, 1);
    expect((await dataSource.albums.getAlbums()).single.imageCount, 1);
  });

  test('deleteAlbum promotes children to root and clears membership', () async {
    final rootId = await dataSource.albums.createAlbum(name: 'root');
    await dataSource.albums.createAlbum(name: 'child', parentId: rootId);
    final imageId = await seedImage('gallery/a.png');
    await dataSource.albums.addImagesToAlbum(rootId, [imageId]);

    expect(await dataSource.albums.deleteAlbum(rootId), isTrue);

    final albums = await dataSource.albums.getAlbums();
    expect(albums, hasLength(1));
    expect(albums.single.name, 'child');
    expect(albums.single.parentId, isNull);
    // 根相簿删除后其成员关系随之清理
    expect(albums.single.imageCount, 0);
  });

  test(
    'getAlbumFilePathsWithDescendants includes descendant members',
    () async {
      final rootId = await dataSource.albums.createAlbum(name: 'root');
      final childId = await dataSource.albums.createAlbum(
        name: 'child',
        parentId: rootId,
      );
      await seedImage('gallery/root.png');
      await seedImage('gallery/child.png');
      final ids = await dataSource.getImageIdsByPaths([
        'gallery/root.png',
        'gallery/child.png',
      ]);
      await dataSource.albums.addImagesToAlbum(rootId, [
        ids['gallery/root.png']!,
      ]);
      await dataSource.albums.addImagesToAlbum(childId, [
        ids['gallery/child.png']!,
      ]);

      final paths = await dataSource.albums.getAlbumFilePathsWithDescendants(
        rootId,
      );

      expect(paths.toSet(), {'gallery/root.png', 'gallery/child.png'});
    },
  );

  test('importAlbums keeps original ids and membership', () async {
    final imageId = await seedImage('gallery/import.png');
    final album = GalleryAlbumRecord(
      id: 'legacy-1',
      name: '迁移相簿',
      parentId: null,
      sortOrder: 3,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    await dataSource.albums.importAlbums(
      [album],
      {
        'legacy-1': [imageId],
      },
    );

    final albums = await dataSource.albums.getAlbums();
    expect(albums.single.id, 'legacy-1');
    expect(albums.single.name, '迁移相簿');
    expect(albums.single.imageCount, 1);
  });

  test('updateFilePath keeps album membership after physical move', () async {
    final albumId = await dataSource.albums.createAlbum(name: 'A');
    await seedImage('gallery/old.png');
    final ids = await dataSource.getImageIdsByPaths(['gallery/old.png']);
    await dataSource.albums.addImagesToAlbum(albumId, [
      ids['gallery/old.png']!,
    ]);

    // 模拟分类移动：物理 rename 后同步库内路径（保留行 id）
    await dataSource.updateFilePath(
      ids['gallery/old.png']!,
      'gallery/folder/old.png',
      newFileName: 'old.png',
    );

    final paths = await dataSource.albums.getAlbumFilePathsWithDescendants(
      albumId,
    );
    expect(paths, ['gallery/folder/old.png']);
    expect((await dataSource.albums.getAlbums()).single.imageCount, 1);
  });

  test('getAllAlbumMemberPaths returns direct members per album', () async {
    final a = await dataSource.albums.createAlbum(name: 'A');
    final b = await dataSource.albums.createAlbum(name: 'B');
    await seedImage('gallery/a.png');
    await seedImage('gallery/b.png');
    final ids = await dataSource.getImageIdsByPaths([
      'gallery/a.png',
      'gallery/b.png',
    ]);
    await dataSource.albums.addImagesToAlbum(a, [ids['gallery/a.png']!]);
    await dataSource.albums.addImagesToAlbum(b, [ids['gallery/b.png']!]);

    final map = await dataSource.albums.getAllAlbumMemberPaths();

    expect(map[a], ['gallery/a.png']);
    expect(map[b], ['gallery/b.png']);
  });

  test(
    'importAlbums accepts out-of-order input (child before parent)',
    () async {
      final parent = GalleryAlbumRecord(
        id: 'p1',
        name: '父',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final child = GalleryAlbumRecord(
        id: 'c1',
        name: '子',
        parentId: 'p1',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      // 子相簿排在父相簿之前，拓扑排序应保证父先写入
      await dataSource.albums.importAlbums([child, parent], const {});

      final albums = await dataSource.albums.getAlbums();
      expect(albums.map((a) => a.id).toList(), ['p1', 'c1']);
      expect(albums[1].parentId, 'p1');
    },
  );

  test(
    'importAlbums re-import keeps parent links (regression for REPLACE)',
    () async {
      final root = GalleryAlbumRecord(
        id: 'root',
        name: 'root',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final child = GalleryAlbumRecord(
        id: 'child',
        name: 'child',
        parentId: 'root',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await dataSource.albums.importAlbums([root, child], const {});

      // 重复导入父相簿：REPLACE 语义曾会经 ON DELETE SET NULL 清空父子关系
      await dataSource.albums.importAlbums([root], const {});

      final albums = await dataSource.albums.getAlbums();
      final childRecord = albums.firstWhere((a) => a.id == 'child');
      expect(childRecord.parentId, 'root');
    },
  );

  test('importAlbums rejects cycles and missing parents', () async {
    final a = GalleryAlbumRecord(
      id: 'a',
      name: 'a',
      parentId: 'b',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
    final b = GalleryAlbumRecord(
      id: 'b',
      name: 'b',
      parentId: 'a',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    await expectLater(
      dataSource.albums.importAlbums([a, b], const {}),
      throwsArgumentError,
    );

    final orphan = GalleryAlbumRecord(
      id: 'orphan',
      name: 'orphan',
      parentId: 'ghost',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
    await expectLater(
      dataSource.albums.importAlbums([orphan], const {}),
      throwsArgumentError,
    );
  });

  test(
    'applyCloudSyncAlbums restores reverse-ordered hierarchy and replaces members',
    () async {
      final oldImageId = await seedImage('gallery/old.png');
      final newImageId = await seedImage('gallery/new.png');
      final parent = GalleryAlbumRecord(
        id: 'cloud-parent',
        name: '父',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final child = GalleryAlbumRecord(
        id: 'cloud-child',
        name: '子',
        parentId: parent.id,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await dataSource.albums.importAlbums(
        [parent],
        {
          parent.id: [oldImageId],
        },
      );

      await dataSource.albums.applyCloudSyncAlbums(
        [child, parent],
        {
          parent.id: [newImageId],
        },
        pendingPathsByAlbumId: const {
          'cloud-child': ['gallery/waiting.png'],
        },
      );

      final albums = await dataSource.albums.getAlbums();
      expect(albums.map((album) => album.id), [parent.id, child.id]);
      expect(albums.last.parentId, parent.id);
      expect(albums.last.pendingPaths, ['gallery/waiting.png']);
      expect(
        await dataSource.albums.getAlbumFilePathsWithDescendants(parent.id),
        ['gallery/new.png'],
      );
    },
  );

  test(
    'applyCloudSyncAlbums rejects an invalid graph before deleting data',
    () async {
      final existing = GalleryAlbumRecord(
        id: 'existing',
        name: 'existing',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await dataSource.albums.importAlbums([existing], const {});
      final orphan = GalleryAlbumRecord(
        id: 'orphan',
        name: 'orphan',
        parentId: 'missing',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      await expectLater(
        dataSource.albums.applyCloudSyncAlbums(
          [orphan],
          const {},
          deletedAlbumIds: const {'existing'},
        ),
        throwsA(isA<Exception>()),
      );

      expect((await dataSource.albums.getAlbums()).single.id, existing.id);
    },
  );

  test(
    'pendingPaths persist and rebindPendingPaths binds resolved ones',
    () async {
      final imageId = await seedImage('gallery/a.png');
      final album = GalleryAlbumRecord(
        id: 'pa',
        name: 'A',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await dataSource.albums.importAlbums(
        [album],
        const {},
        pendingPathsByAlbumId: const {
          'pa': ['gallery/a.png', 'gallery/missing.png'],
        },
      );

      var readBack = (await dataSource.albums.getAlbums()).single;
      expect(readBack.pendingPaths, ['gallery/a.png', 'gallery/missing.png']);

      // 模拟扫描完成后补绑：可解析的绑定，仍缺的保留在 pending
      final remaining = await dataSource.albums.rebindPendingPaths(
        resolve: (paths) async {
          final ids = await dataSource.getImageIdsByPaths([
            'gallery/a.png',
            'gallery/missing.png',
          ]);
          return {for (final path in paths) path: ids[path]};
        },
      );

      expect(remaining, 1);
      readBack = (await dataSource.albums.getAlbums()).single;
      expect(readBack.pendingPaths, ['gallery/missing.png']);
      expect(readBack.imageCount, 1);
      expect(imageId, greaterThan(0));
    },
  );

  test(
    'rebindPendingPaths does not overwrite a concurrent cloud snapshot',
    () async {
      final staleImageId = await seedImage('gallery/stale.png');
      final album = GalleryAlbumRecord(
        id: 'race',
        name: 'race',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await dataSource.albums.importAlbums(
        [album],
        const {},
        pendingPathsByAlbumId: const {
          'race': ['gallery/stale.png'],
        },
      );

      final resolveStarted = Completer<void>();
      final continueResolve = Completer<void>();
      final rebind = dataSource.albums.rebindPendingPaths(
        resolve: (paths) async {
          resolveStarted.complete();
          await continueResolve.future;
          return {'gallery/stale.png': staleImageId};
        },
      );
      await resolveStarted.future;

      await dataSource.albums.applyCloudSyncAlbums(
        [album],
        const {},
        pendingPathsByAlbumId: const {
          'race': ['gallery/current.png'],
        },
      );
      continueResolve.complete();
      await rebind;

      final restored = (await dataSource.albums.getAlbums()).single;
      expect(restored.pendingPaths, ['gallery/current.png']);
      expect(restored.imageCount, 0);
    },
  );
}
