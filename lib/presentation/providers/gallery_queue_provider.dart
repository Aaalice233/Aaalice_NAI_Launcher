import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/services/gallery_generation_queue_service.dart';

part 'gallery_queue_provider.g.dart';

/// 画廊生成队列 Provider
///
/// 管理从画廊发送到生成队列的项
@riverpod
class GalleryQueueNotifier extends _$GalleryQueueNotifier {
  final _queueService = GalleryGenerationQueueService();

  @override
  void build() {}

  /// 批量发送到主页队列
  ///
  /// [posts] 选中的 Danbooru 帖子列表
  /// [format] 提示词格式 ('raw' 或 'nai')
  Future<void> sendToHome(
    Iterable<DanbooruPost> posts, {
    String format = 'raw',
  }) async {
    // 添加到队列
    _queueService.addAllToQueue(posts, format: format);
  }

  /// 获取队列长度
  int get queueLength => _queueService.length;

  /// 获取队列是否为空
  bool get isEmpty => _queueService.isEmpty;

  /// 清空队列
  void clearQueue() {
    _queueService.clearQueue();
  }
}
