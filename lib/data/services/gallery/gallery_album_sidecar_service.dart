import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../../models/gallery/gallery_album.dart';

/// 相簿 sidecar 的一次完整快照
///
/// 跟随图片库根目录存储（.gallery_albums.json），拷贝图库目录到其他
/// 设备时相簿定义随之带走；成员以相对路径记录保证跨设备可用。
class GalleryAlbumSidecar {
  static const int currentVersion = 1;

  final List<GalleryAlbum> albums;

  /// albumId -> 相对图库根目录的图片路径列表（'/' 分隔）
  final Map<String, List<String>> imagePathsByAlbumId;

  const GalleryAlbumSidecar({
    required this.albums,
    required this.imagePathsByAlbumId,
  });

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'albums': [
      for (final album in albums)
        {
          ...album.toJson(),
          'images': imagePathsByAlbumId[album.id] ?? const <String>[],
        },
    ],
  };

  static GalleryAlbumSidecar? fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt();
    if (version == null || version > currentVersion) return null;

    final albumJsons = json['albums'];
    if (albumJsons is! List) {
      return const GalleryAlbumSidecar(albums: [], imagePathsByAlbumId: {});
    }

    final albums = <GalleryAlbum>[];
    final imagePaths = <String, List<String>>{};
    for (final item in albumJsons) {
      if (item is! Map<String, dynamic>) continue;
      final Map<String, dynamic> albumJson = Map.from(item);
      final images =
          (albumJson.remove('images') as List?)?.whereType<String>().toList() ??
          const <String>[];
      try {
        final album = GalleryAlbum.fromJson(albumJson);
        albums.add(album);
        imagePaths[album.id] = images;
      } catch (e) {
        AppLogger.w('跳过无法解析的相簿条目: $e', 'AlbumSidecar');
      }
    }
    return GalleryAlbumSidecar(albums: albums, imagePathsByAlbumId: imagePaths);
  }
}

/// 读写图片库根目录下的相簿 sidecar 文件
class GalleryAlbumSidecarService {
  static const String fileName = '.gallery_albums.json';

  File _sidecarFile(String rootPath) => File(p.join(rootPath, fileName));

  /// 读取 sidecar；文件不存在或版本不受支持时返回 null
  Future<GalleryAlbumSidecar?> read(String rootPath) async {
    try {
      final file = _sidecarFile(rootPath);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return GalleryAlbumSidecar.fromJson(decoded);
    } catch (e) {
      AppLogger.e('读取相簿 sidecar 失败', e, null, 'AlbumSidecar');
      return null;
    }
  }

  /// 原子写入 sidecar（先写临时文件再替换）
  Future<bool> write(String rootPath, GalleryAlbumSidecar sidecar) async {
    try {
      final file = _sidecarFile(rootPath);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(sidecar.toJson()),
      );
      await tmp.rename(file.path);
      return true;
    } catch (e) {
      AppLogger.e('写入相簿 sidecar 失败', e, null, 'AlbumSidecar');
      return false;
    }
  }

  /// 绝对路径 -> 相对图库根目录的 '/' 分隔路径；不在根目录下时返回 null
  static String? toRelativePath(String rootPath, String absolutePath) {
    final normalizedRoot = p.normalize(rootPath);
    final normalized = p.normalize(absolutePath);
    if (!p.isWithin(normalizedRoot, normalized)) return null;
    return p.relative(normalized, from: normalizedRoot).replaceAll('\\', '/');
  }

  /// 相对路径 -> 绝对路径
  static String toAbsolutePath(String rootPath, String relativePath) {
    return p.joinAll([p.normalize(rootPath), ...relativePath.split('/')]);
  }
}
