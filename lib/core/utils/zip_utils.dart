import 'dart:typed_data';

import 'package:archive/archive.dart';

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
          if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
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
  static List<({String name, Uint8List data})> extractImagesWithNames(Uint8List zipBytes) {
    final results = <({String name, Uint8List data})>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
            results.add((
              name: file.name,
              data: Uint8List.fromList(file.content as List<int>),
            ));
          }
        }
      }
    } catch (e) {
      // 解压失败返回空列表
    }

    return results;
  }
}
