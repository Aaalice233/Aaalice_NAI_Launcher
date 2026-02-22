import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/remote/danbooru_pool_service.dart';
import '../../data/datasources/remote/danbooru_tag_group_service.dart';

part 'danbooru_preview_provider.g.dart';

/// Tag Group 预览数据
class TagGroupPreview {
  /// 标签总数
  final int tagCount;

  /// 前 N 个高频标签（名称列表）
  final List<String> topTags;

  /// 分组标题
  final String title;

  const TagGroupPreview({
    required this.tagCount,
    required this.topTags,
    required this.title,
  });

  static const empty = TagGroupPreview(
    tagCount: 0,
    topTags: [],
    title: '',
  );
}

/// Pool 预览数据
class PoolPreview {
  /// 帖子总数
  final int postCount;

  /// 前 N 个帖子的缩略图 URL
  final List<String> thumbnailUrls;

  /// Pool 名称
  final String name;

  /// Pool 描述
  final String description;

  const PoolPreview({
    required this.postCount,
    required this.thumbnailUrls,
    required this.name,
    required this.description,
  });

  static const empty = PoolPreview(
    postCount: 0,
    thumbnailUrls: [],
    name: '',
    description: '',
  );
}

/// 获取 Tag Group 预览数据
@riverpod
Future<TagGroupPreview> tagGroupPreview(
  Ref ref,
  String groupTitle,
) async {
  final service = ref.watch(danbooruTagGroupServiceProvider);

  final group = await service.getTagGroup(groupTitle, fetchPostCounts: true);
  if (group == null) {
    return TagGroupPreview.empty;
  }

  // 获取前 10 个高频标签
  final topTags = group.tags.take(10).map((t) => t.displayName).toList();

  return TagGroupPreview(
    tagCount: group.tagCount,
    topTags: topTags,
    title: group.title,
  );
}

/// 获取 Pool 预览数据
@riverpod
Future<PoolPreview> poolPreview(
  Ref ref,
  int poolId,
) async {
  final service = ref.watch(danbooruPoolServiceProvider);

  final pool = await service.getPool(poolId);
  if (pool == null) {
    return PoolPreview.empty;
  }

  // Pool 模型已包含 postCount 和基本信息
  // 缩略图需要从帖子获取，但这里简化处理，只返回基本信息
  return PoolPreview(
    postCount: pool.postCount,
    thumbnailUrls: [], // 缩略图暂不加载，避免额外请求
    name: pool.displayName,
    description: pool.description,
  );
}
