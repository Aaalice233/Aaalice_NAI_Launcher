import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Danbooru 图片缓存管理器
///
/// 使用自定义配置提升图片加载性能：
/// - 最大缓存对象数：1000（支持大量图片）
/// - 过期时间：7天
/// - 支持 HTTP/2（通过全局 Dio 实例）
class DanbooruImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'danbooruImageCache';

  static final DanbooruImageCacheManager _instance =
      DanbooruImageCacheManager._internal();

  factory DanbooruImageCacheManager() => _instance;

  DanbooruImageCacheManager._internal()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 1000,
          ),
        );

  /// 获取单例实例
  static DanbooruImageCacheManager get instance => _instance;
}
