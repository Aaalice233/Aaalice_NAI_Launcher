import 'package:freezed_annotation/freezed_annotation.dart';

part 'gallery_folder.freezed.dart';
part 'gallery_folder.g.dart';

/// 画廊文件夹模型
@freezed
class GalleryFolder with _$GalleryFolder {
  const factory GalleryFolder({
    required String id, // 文件夹ID (基于路径生成的唯一标识)
    required String name, // 文件夹名称
    required String path, // 文件夹完整路径
    @Default(0) int imageCount, // 文件夹内图片数量
    required DateTime createdAt, // 创建时间
    DateTime? modifiedAt, // 最后修改时间
  }) = _GalleryFolder;

  const GalleryFolder._();

  factory GalleryFolder.fromJson(Map<String, dynamic> json) =>
      _$GalleryFolderFromJson(json);

  /// 文件夹是否为空
  bool get isEmpty => imageCount == 0;

  /// 文件夹是否非空
  bool get isNotEmpty => imageCount > 0;
}
