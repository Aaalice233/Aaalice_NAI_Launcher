import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_collection.freezed.dart';
part 'image_collection.g.dart';

/// 图片集合模型
@freezed
class ImageCollection with _$ImageCollection {
  const factory ImageCollection({
    required String id, // 集合ID
    required String name, // 集合名称
    String? description, // 集合描述
    @Default([]) List<String> imagePaths, // 图片路径列表
    required DateTime createdAt, // 创建时间
  }) = _ImageCollection;

  const ImageCollection._();

  factory ImageCollection.fromJson(Map<String, dynamic> json) =>
      _$ImageCollectionFromJson(json);

  /// 集合是否为空
  bool get isEmpty => imagePaths.isEmpty;

  /// 集合是否非空
  bool get isNotEmpty => imagePaths.isNotEmpty;

  /// 集合中的图片数量
  int get imageCount => imagePaths.length;
}
