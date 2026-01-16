import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/models/image/image_params.dart';
import 'gallery_prompt_service.dart';
import 'resolution_matcher.dart';

/// 排队项
class QueuedItem {
  final DanbooruPost post;
  final String prompt;
  final String format; // 'raw' 或 'nai'
  final DateTime addedAt;

  QueuedItem({
    required this.post,
    required this.prompt,
    this.format = 'raw',
    required this.addedAt,
  });
}

/// 生成队列服务
///
/// 管理从画廊添加到生成队列的项，支持批量添加和 ImageParams 转换
class GalleryGenerationQueueService {
  final List<QueuedItem> _queue = [];
  final _promptService = GalleryPromptService();
  final _resolutionMatcher = ResolutionMatcher();

  /// 队列（不可修改视图）
  List<QueuedItem> get queue => List.unmodifiable(_queue);

  /// 队列是否为空
  bool get isEmpty => _queue.isEmpty;

  /// 队列长度
  int get length => _queue.length;

  /// 添加到队列
  ///
  /// [post] Danbooru 帖子
  /// [format] 提示词格式 ('raw' 或 'nai')
  void addToQueue(DanbooruPost post, {String format = 'raw'}) {
    final prompt = format == 'nai'
        ? _promptService.toNaiFormat(post.tags)
        : _promptService.toRawTags(post);

    _queue.add(QueuedItem(
      post: post,
      prompt: prompt,
      format: format,
      addedAt: DateTime.now(),
    ));
  }

  /// 批量添加到队列
  void addAllToQueue(Iterable<DanbooruPost> posts, {String format = 'raw'}) {
    for (final post in posts) {
      addToQueue(post, format: format);
    }
  }

  /// 处理队列项，返回 ImageParams
  ///
  /// [index] 队列索引
  Future<ImageParams> processQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) {
      throw ArgumentError('Invalid queue index: $index');
    }

    final item = _queue[index];
    final preset = _resolutionMatcher.matchBestResolution(
      item.post.width,
      item.post.height,
    );

    return ImageParams(
      prompt: item.prompt,
      negativePrompt: '', // 空字符串让后端自动填充
      width: preset.width,
      height: preset.height,
      nSamples: 1,
    );
  }

  /// 移除队列项
  ///
  /// [index] 队列索引
  void removeItem(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
    }
  }

  /// 清空队列
  void clearQueue() {
    _queue.clear();
  }
}
