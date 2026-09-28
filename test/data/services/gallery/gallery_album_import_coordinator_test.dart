import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/image_collection.dart';
import 'package:nai_launcher/data/services/gallery/gallery_album_import_coordinator.dart';
import 'package:nai_launcher/data/services/gallery/gallery_album_sidecar_service.dart';

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values[key] as T? ?? defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

class _FakeSidecar extends GalleryAlbumSidecarService {
  GalleryAlbumSidecar? payload;

  @override
  Future<GalleryAlbumSidecar?> read(String rootPath) async => payload;

  @override
  Future<bool> write(String rootPath, GalleryAlbumSidecar sidecar) async =>
      true;
}

String posixJoin(String path) => path.split(Platform.pathSeparator).join('/');

GalleryAlbum _album(String id, {String? parentId}) => GalleryAlbum(
  id: id,
  name: id,
  parentId: parentId,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

/// 相簿一次性导入协调器测试（启动接线幂等、pending 保留）
void main() {
  late GalleryDataSource dataSource;
  late String testDbPath;
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  tearDownAll(() async {
    await ConnectionPoolHolder.dispose();
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('album_import_test_');
    testDbPath = '${tempDir.path}/test.db';
    if (ConnectionPoolHolder.isInitialized) {
      await ConnectionPoolHolder.dispose();
    }
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
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<int> seedImage(String path) async {
    final now = DateTime.now();
    return dataSource.upsertImage(
      filePath: path,
      fileName: path.split('/').last,
      fileSize: 16,
      createdAt: now,
      modifiedAt: now,
    );
  }

  test('imports albums, keeps unindexed existing files as pending', () async {
    // gallery/a.png 已索引；gallery/b.png 存在于文件系统但未索引 → pending；
    // gallery/missing.png 不存在 → 跳过
    Directory('${tempDir.path}/gallery').createSync(recursive: true);
    // 与协调器一致的绝对路径形式（p.joinAll，平台分隔符）
    final seededPath = GalleryAlbumSidecarService.toAbsolutePath(
      tempDir.path,
      'gallery/a.png',
    );
    await seedImage(seededPath);
    File(
      GalleryAlbumSidecarService.toAbsolutePath(tempDir.path, 'gallery/b.png'),
    ).writeAsStringSync('x');
    final rootPath = tempDir.path;

    final sidecar = _FakeSidecar()
      ..payload = GalleryAlbumSidecar(
        albums: [_album('a1')],
        imagePathsByAlbumId: {
          'a1': ['gallery/a.png', 'gallery/b.png', 'gallery/missing.png'],
        },
      );
    const legacy = <ImageCollection>[];
    final storage = _MemoryLocalStorage();
    final coordinator = GalleryAlbumImportCoordinator(
      dataSource: dataSource,
      localStorage: storage,
      sidecarService: sidecar,
      readLegacyCollections: () => legacy,
    )..galleryRootPathOverride = rootPath;

    await coordinator.importIfNeeded();

    final albums = await dataSource.albums.getAlbums();
    expect(albums, hasLength(1));
    // 已索引成员 + 待补绑成员；缺失文件被跳过
    final record = (await dataSource.albums.getAlbums()).single;
    expect(record.pendingPaths, ['gallery/b.png']);
    expect(albums.single.imageCount, 1);
    // 标记已写入：再次执行不会重复导入
    expect(storage.values['gallery_album_import_done_v1'], isTrue);
  });

  test('importIfNeeded is idempotent across runs', () async {
    final sidecar = _FakeSidecar()
      ..payload = GalleryAlbumSidecar(
        albums: [_album('a1')],
        imagePathsByAlbumId: const {},
      );
    final storage = _MemoryLocalStorage();
    final coordinator = GalleryAlbumImportCoordinator(
      dataSource: dataSource,
      localStorage: storage,
      sidecarService: sidecar,
      readLegacyCollections: () => const <ImageCollection>[],
    )..galleryRootPathOverride = tempDir.path;

    await coordinator.importIfNeeded();
    await coordinator.importIfNeeded();

    expect(await dataSource.albums.getAlbums(), hasLength(1));
  });

  test('falls back to legacy collections when no sidecar exists', () async {
    Directory('${tempDir.path}/gallery').createSync(recursive: true);
    final seededPath = GalleryAlbumSidecarService.toAbsolutePath(
      tempDir.path,
      'gallery/a.png',
    );
    await seedImage(seededPath);

    var legacy = const <ImageCollection>[];
    legacy = [
      ImageCollection(
        id: 'c1',
        name: '旧集合',
        imagePaths: [seededPath],
        createdAt: DateTime(2025, 1, 1),
      ),
    ];
    final coordinator = GalleryAlbumImportCoordinator(
      dataSource: dataSource,
      localStorage: _MemoryLocalStorage(),
      sidecarService: _FakeSidecar(),
      readLegacyCollections: () => legacy,
    )..galleryRootPathOverride = tempDir.path;

    await coordinator.importIfNeeded();

    final albums = await dataSource.albums.getAlbums();
    expect(albums.single.id, 'c1');
    expect(albums.single.name, '旧集合');
    expect(albums.single.imageCount, 1);
  });

  test('旧集合的失效绝对路径按后缀重挂到当前图库根目录', () async {
    // 模拟 iOS 覆盖安装：旧集合记的是上一个容器 UUID 下的绝对路径，
    // 文件其实还在当前图库根目录的同一相对位置上。
    final rootPath = GalleryAlbumSidecarService.toAbsolutePath(
      tempDir.path,
      'Containers/NEW-UUID/Documents/gallery',
    );
    Directory(
      GalleryAlbumSidecarService.toAbsolutePath(rootPath, '2025'),
    ).createSync(recursive: true);
    final livePath = GalleryAlbumSidecarService.toAbsolutePath(
      rootPath,
      '2025/a.png',
    );
    File(livePath).writeAsStringSync('x');
    await seedImage(livePath);

    const stalePath =
        '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
        'gallery/2025/a.png';
    const gonePath =
        '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
        'gallery/2025/gone.png';
    final legacy = [
      ImageCollection(
        id: 'c1',
        name: '旧集合',
        imagePaths: const [stalePath, gonePath],
        createdAt: DateTime(2025, 1, 1),
      ),
    ];
    final coordinator = GalleryAlbumImportCoordinator(
      dataSource: dataSource,
      localStorage: _MemoryLocalStorage(),
      sidecarService: _FakeSidecar(),
      readLegacyCollections: () => legacy,
    )..galleryRootPathOverride = rootPath;

    await coordinator.importIfNeeded();

    final albums = await dataSource.albums.getAlbums();
    expect(albums.single.id, 'c1');
    // 换过容器路径的成员被救回来，真正消失的那个才计入跳过
    expect(albums.single.imageCount, 1);
    expect(coordinator.rebasedImageCount, 1);
    expect(coordinator.skippedImageCount, 1);
  });
}
