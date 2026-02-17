import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database_providers.dart';
import 'danbooru_tag_datasource_v2.dart';

part 'danbooru_tag_datasource_v2_provider.g.dart';

/// Danbooru 标签数据源 Provider (V2)
/// 
/// 每次获取时创建新实例，自动使用当前有效的 ConnectionPool
@Riverpod(keepAlive: true)
Future<DanbooruTagDataSourceV2> danbooruTagDataSourceV2(Ref ref) async {
  // 等待数据库管理器就绪
  await ref.watch(databaseManagerProvider.future);
  
  // 创建数据源实例
  final dataSource = DanbooruTagDataSourceV2();
  await dataSource.initialize();
  
  return dataSource;
}
