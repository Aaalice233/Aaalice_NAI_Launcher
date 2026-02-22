import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

/// ZIP 工具类 - 处理 NovelAI 返回的 ZIP 响应
class ZipUtils {
  ZipUtils._();

  /// 从 ZIP 二进制数据中提取第一张 PNG 图片
  ///
  /// NovelAI 的图像生成 API 返回 ZIP 格式的响应，
  /// 其中包含一个或多个 PNG 图片文件
  static Uint8List? extractFirstImage(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile && file.name.toLowerCase().endsWith('.png')) {
          return Uint8List.fromList(file.content as List<int>);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 从 ZIP 中提取所有图片
  static List<Uint8List> extractAllImages(Uint8List zipBytes) {
    final images = <Uint8List>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.png') ||
              name.endsWith('.jpg') ||
              name.endsWith('.jpeg')) {
            images.add(Uint8List.fromList(file.content as List<int>));
          }
        }
      }
    } catch (e) {
      // 解压失败返回空列表
    }

    return images;
  }

  /// 从 ZIP 中提取图片及其文件名
  static List<({String name, Uint8List data})> extractImagesWithNames(
    Uint8List zipBytes,
  ) {
    final results = <({String name, Uint8List data})>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.png') ||
              name.endsWith('.jpg') ||
              name.endsWith('.jpeg')) {
            results.add(
              (
                name: file.name,
                data: Uint8List.fromList(file.content as List<int>),
              ),
            );
          }
        }
      }
    } catch (e) {
      // 解压失败返回空列表
    }

    return results;
  }

  /// 将多个图片文件打包成 ZIP 文件
  ///
  /// [imagePaths] 图片文件路径列表
  /// [outputPath] 输出 ZIP 文件的完整路径
  /// [onProgress] 进度回调 (当前索引, 总数)
  /// 返回是否成功
  static Future<bool> createZipFromImages(
    List<String> imagePaths,
    String outputPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      final archive = Archive();

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final file = File(imagePath);

        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path.basename(imagePath);

          archive.addFile(
            ArchiveFile(
              fileName,
              bytes.length,
              bytes,
            ),
          );
        }

        onProgress?.call(i + 1, imagePaths.length);
      }

      if (archive.isEmpty) {
        return false;
      }

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null) {
        return false;
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 将多个图片文件打包成 ZIP 字节数据
  ///
  /// [imagePaths] 图片文件路径列表
  /// 返回 ZIP 的字节数据，失败返回 null
  static Future<Uint8List?> createZipBytesFromImages(
    List<String> imagePaths,
  ) async {
    try {
      final archive = Archive();

      for (final imagePath in imagePaths) {
        final file = File(imagePath);

        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path.basename(imagePath);

          archive.addFile(
            ArchiveFile(
              fileName,
              bytes.length,
              bytes,
            ),
          );
        }
      }

      if (archive.isEmpty) {
        return null;
      }

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      return zipData != null ? Uint8List.fromList(zipData) : null;
    } catch (e) {
      return null;
    }
  }
}
