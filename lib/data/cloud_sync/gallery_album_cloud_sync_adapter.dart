import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/gallery/gallery_album.dart';
import '../services/gallery/gallery_album_sidecar_service.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

/// 图库相簿云同步适配器
///
/// 同步相簿定义与成员引用（相对图库根目录的路径），不同步图片本体；
/// 与在线收藏等适配器一致无条件参与同步。旧数据格式（v1）不含
/// coverPath / description 字段时按缺省处理。
class GalleryAlbumCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  GalleryAlbumCloudSyncAdapter({
    required this.readAlbums,
    required this.readMemberPaths,
    required this.upsertAlbum,
    required this.deleteAlbum,
    required this.getRootPath,
  });

  final Future<List<GalleryAlbum>> Function() readAlbums;
  final Future<Map<String, List<String>>> Function() readMemberPaths;
  final Future<void> Function(
    GalleryAlbum album,
    List<String> imagePaths,
    List<String> pendingPaths,
  )
  upsertAlbum;
  final Future<void> Function(String albumId) deleteAlbum;
  final Future<String?> Function() getRootPath;

  @override
  String get id => 'gallery-albums';

  @override
  Set<String> get allowedKinds => const {'album'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    final albums = await readAlbums();
    if (albums.isEmpty) return;
    final memberPaths = await readMemberPaths();
    final rootPath = await getRootPath();

    for (final album in albums) {
      // 只上传图库根目录内的规范化相对路径；无法相对化的路径跳过并记录，
      // 绝不上传设备绝对路径（可能泄露盘符、用户名）
      final images = [
        for (final path in memberPaths[album.id] ?? const <String>[])
          if (rootPath != null && rootPath.isNotEmpty)
            GalleryAlbumSidecarService.toRelativePath(rootPath, path),
        ...album.pendingPaths,
      ].whereType<String>().toList();
      final coverPath =
          album.coverPath == null || rootPath == null || rootPath.isEmpty
          ? null
          : GalleryAlbumSidecarService.toRelativePath(
              rootPath,
              album.coverPath!,
            );
      yield PortableSyncRecord(
        adapterId: id,
        id: _portableId(album.id),
        kind: 'album',
        data: {
          'albumId': album.id,
          'name': album.name,
          'description': album.description,
          'parentId': album.parentId,
          'sortOrder': album.sortOrder,
          'coverPath': coverPath,
          'createdAt': album.createdAt.millisecondsSinceEpoch,
          'updatedAt': album.updatedAt.millisecondsSinceEpoch,
          'images': images,
        },
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    final albumId = record.data['albumId'];
    if (albumId is! String || albumId.isEmpty) {
      throw const CloudSyncPreflightException('Album record lacks albumId');
    }
    if (record.id != _portableId(albumId)) {
      throw const CloudSyncPreflightException('Album identity mismatch');
    }
    if (record.data['name'] is! String) {
      throw const CloudSyncPreflightException('Album record lacks name');
    }
    if (record.data['images'] is! List) {
      throw const CloudSyncPreflightException('Album record lacks images');
    }
    final images = (record.data['images']! as List).whereType<String>();
    for (final imagePath in images) {
      if (!GalleryAlbumSidecarService.isValidRelativeMemberPath(imagePath)) {
        throw CloudSyncPreflightException(
          'Album member path is not a normalized relative path: $imagePath',
        );
      }
    }
    final coverPath = record.data['coverPath'];
    if (coverPath is String &&
        !GalleryAlbumSidecarService.isValidRelativeMemberPath(coverPath)) {
      throw const CloudSyncPreflightException(
        'Album cover path is not a normalized relative path',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      final albumId = record.data['albumId']! as String;
      if (record.deleted) {
        await deleteAlbum(albumId);
        continue;
      }

      final images = (record.data['images']! as List)
          .whereType<String>()
          .toList();
      // 图片尚可解析的成员先记录待绑定：新设备图库未完成扫描时不丢引用
      await upsertAlbum(
        GalleryAlbum(
          id: albumId,
          name: record.data['name']! as String,
          description: record.data['description'] as String?,
          parentId: record.data['parentId'] as String?,
          sortOrder: (record.data['sortOrder'] as num?)?.toInt() ?? 0,
          coverPath: record.data['coverPath'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (record.data['createdAt'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (record.data['updatedAt'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          ),
        ),
        images,
        const [],
      );
    }
  }

  String _portableId(String albumId) {
    return 'album-${sha256.convert(utf8.encode(albumId)).toString()}';
  }
}
