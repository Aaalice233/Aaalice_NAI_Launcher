import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/services/gallery/gallery_album_sidecar_service.dart';

/// 相簿 sidecar 读写与路径转换测试
void main() {
  late Directory tempDir;
  late String rootPath;
  final service = GalleryAlbumSidecarService();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('album_sidecar_test_');
    rootPath = tempDir.path;
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  GalleryAlbum album({required String id, String? parentId}) {
    return GalleryAlbum(
      id: id,
      name: '相簿$id',
      parentId: parentId,
      createdAt: DateTime(2025, 6, 1),
      updatedAt: DateTime(2025, 6, 1),
    );
  }

  test('write and read roundtrip preserves albums and member paths', () async {
    final sidecar = GalleryAlbumSidecar(
      albums: [
        album(id: 'a1'),
        album(id: 'a2', parentId: 'a1'),
      ],
      imagePathsByAlbumId: {
        'a1': ['2025/08/img.png'],
        'a2': ['2025/08/other.png'],
      },
    );

    expect(await service.write(rootPath, sidecar), isTrue);
    final loaded = await service.read(rootPath);

    expect(loaded, isNotNull);
    expect(loaded!.albums, hasLength(2));
    expect(loaded.albums.first.name, '相簿a1');
    expect(loaded.imagePathsByAlbumId['a2'], ['2025/08/other.png']);
  });

  test('read returns null when sidecar is missing', () async {
    expect(await service.read(rootPath), isNull);
  });

  test('read returns null for unsupported future version', () async {
    final file = File(
      '$rootPath${Platform.pathSeparator}${GalleryAlbumSidecarService.fileName}',
    );
    await file.writeAsString('{"version": 99, "albums": []}');

    expect(await service.read(rootPath), isNull);
  });

  test('toRelativePath normalizes separators and rejects outside paths', () {
    final key = GalleryAlbumSidecarService.toRelativePath(
      rootPath,
      '$rootPath${Platform.pathSeparator}sub${Platform.pathSeparator}img.png',
    );

    expect(key, 'sub/img.png');
    expect(
      GalleryAlbumSidecarService.toRelativePath(
        rootPath,
        'C:${Platform.pathSeparator}elsewhere${Platform.pathSeparator}img.png',
      ),
      isNull,
    );
  });

  test('toAbsolutePath joins root with relative segments', () {
    final absolute = GalleryAlbumSidecarService.toAbsolutePath(
      rootPath,
      'sub/img.png',
    );
    final normalized = absolute.replaceAll('\\', '/');
    final root = rootPath.replaceAll('\\', '/');
    expect(normalized, '$root/sub/img.png');
  });
}
