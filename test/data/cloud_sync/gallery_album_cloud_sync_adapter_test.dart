import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/gallery_album_cloud_sync_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/portable_sync_record.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';

GalleryAlbum _album({
  String id = 'a1',
  String? parentId,
  String? coverPath,
  List<String> pendingPaths = const [],
}) {
  return GalleryAlbum(
    id: id,
    name: id,
    parentId: parentId,
    coverPath: coverPath,
    pendingPaths: pendingPaths,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  GalleryAlbumCloudSyncAdapter build({
    List<GalleryAlbum> albums = const [],
    Map<String, List<String>> memberPaths = const {},
    String? rootPath,
  }) {
    return GalleryAlbumCloudSyncAdapter(
      readAlbums: () async => albums,
      readMemberPaths: () async => memberPaths,
      upsertAlbum: (album, imagePaths, pendingPaths) async {},
      deleteAlbum: (albumId) async {},
      getRootPath: () async => rootPath,
    );
  }

  test(
    'export skips paths outside gallery root and never uploads absolutes',
    () async {
      final adapter = build(
        albums: [_album()],
        memberPaths: {
          'a1': [
            'C:\\Users\\someone\\gallery\\leak.png', // 图库外（绝对路径）
            'D:/other/x.png', // 盘符形式
          ],
        },
        rootPath: r'D:\gallery',
      );

      final records = await adapter.exportRecords().toList();
      expect(records, hasLength(1));
      final images = records.single.data['images']! as List;
      // 无法相对化的成员被跳过，绝不回退上传原路径
      expect(images, isEmpty);
    },
  );

  test('export includes pending paths and relativizes cover', () async {
    final adapter = build(
      albums: [
        _album(
          coverPath: r'D:\gallery\covers\c.png',
          pendingPaths: const ['gallery/waiting.png'],
        ),
      ],
      memberPaths: const {
        'a1': [r'D:\gallery\2025\a.png'],
      },
      rootPath: r'D:\gallery',
    );

    final records = await adapter.exportRecords().toList();
    final data = records.single.data;
    expect(data['images'], ['2025/a.png', 'gallery/waiting.png']);
    expect(data['coverPath'], 'covers/c.png');
  });

  test(
    'validateRecord rejects absolute, traversal and backslash paths',
    () async {
      final adapter = build();

      final portableId =
          'album-${crypto.sha256.convert(utf8.encode('x')).toString()}';
      PortableSyncRecord recordWith(String imagePath) {
        return PortableSyncRecord(
          adapterId: adapter.id,
          id: portableId,
          kind: 'album',
          data: {
            'albumId': 'x',
            'name': 'x',
            'images': [imagePath],
          },
        );
      }

      expect(
        () => adapter.validateRecord(recordWith('/abs/path.png')),
        throwsA(isA<CloudSyncPreflightException>()),
      );
      expect(
        () => adapter.validateRecord(recordWith(r'C:\users\leak.png')),
        throwsA(isA<CloudSyncPreflightException>()),
      );
      expect(
        () => adapter.validateRecord(recordWith('a/../../escape.png')),
        throwsA(isA<CloudSyncPreflightException>()),
      );
      expect(
        () => adapter.validateRecord(recordWith(r'a\b.png')),
        throwsA(isA<CloudSyncPreflightException>()),
      );

      // 合法相对路径通过
      adapter.validateRecord(recordWith('2025/08/img.png'));
    },
  );

  test('validateRecord rejects absolute cover path', () {
    final adapter = build();
    final portableId =
        'album-${crypto.sha256.convert(utf8.encode('x')).toString()}';
    final record = PortableSyncRecord(
      adapterId: adapter.id,
      id: portableId,
      kind: 'album',
      data: {
        'albumId': 'x',
        'name': 'x',
        'images': const <String>[],
        'coverPath': '/etc/passwd.png',
      },
    );

    expect(
      () => adapter.validateRecord(record),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });
}
