import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/gallery_generation_queue_service.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';

void main() {
  group('GalleryGenerationQueueService', () {
    test('addToQueue 应添加到队列末尾', () {
      final service = GalleryGenerationQueueService();
      final post = DanbooruPost(id: 123, tagString: '1girl', width: 1024, height: 1024);

      service.addToQueue(post);

      expect(service.queue.length, 1);
      expect(service.queue.first.post.id, 123);
    });

    test('addToQueue 默认格式为 raw', () {
      final service = GalleryGenerationQueueService();
      final post = DanbooruPost(id: 123, tagString: '1girl');

      service.addToQueue(post);

      expect(service.queue.first.format, 'raw');
    });

    test('addToQueue 支持 nai 格式', () {
      final service = GalleryGenerationQueueService();
      final post = DanbooruPost(id: 123, tagString: '1girl');

      service.addToQueue(post, format: 'nai');

      expect(service.queue.first.format, 'nai');
    });

    test('clearQueue 应清空队列', () {
      final service = GalleryGenerationQueueService();
      final post = DanbooruPost(id: 123, tagString: '1girl');
      service.addToQueue(post);

      service.clearQueue();

      expect(service.queue, isEmpty);
    });

    test('isEmpty 应反映队列状态', () {
      final service = GalleryGenerationQueueService();

      expect(service.isEmpty, isTrue);

      service.addToQueue(DanbooruPost(id: 1, tagString: '1girl'));
      expect(service.isEmpty, isFalse);

      service.clearQueue();
      expect(service.isEmpty, isTrue);
    });

    test('length 应返回队列长度', () {
      final service = GalleryGenerationQueueService();

      expect(service.length, 0);

      service.addToQueue(DanbooruPost(id: 1, tagString: '1girl'));
      expect(service.length, 1);

      service.addToQueue(DanbooruPost(id: 2, tagString: 'blue_hair'));
      expect(service.length, 2);
    });

    test('addAllToQueue 应批量添加', () {
      final service = GalleryGenerationQueueService();
      final posts = [
        DanbooruPost(id: 1, tagString: '1girl'),
        DanbooruPost(id: 2, tagString: 'blue_hair'),
        DanbooruPost(id: 3, tagString: 'solo'),
      ];

      service.addAllToQueue(posts);

      expect(service.length, 3);
    });

    test('removeItem 应移除指定项', () {
      final service = GalleryGenerationQueueService();
      service.addToQueue(DanbooruPost(id: 1, tagString: '1girl'));
      service.addToQueue(DanbooruPost(id: 2, tagString: 'blue_hair'));
      service.addToQueue(DanbooruPost(id: 3, tagString: 'solo'));

      service.removeItem(1);

      expect(service.length, 2);
      expect(service.queue.first.post.id, 1);
      expect(service.queue.last.post.id, 3);
    });

    test('processQueueItem 应返回正确的 ImageParams', () async {
      final service = GalleryGenerationQueueService();
      final post = DanbooruPost(id: 123, tagString: '1girl', width: 1024, height: 1024);
      service.addToQueue(post);

      final params = await service.processQueueItem(0);

      expect(params.prompt, contains('1girl'));
      expect(params.width, greaterThan(0));
      expect(params.height, greaterThan(0));
    });

    test('processQueueItem 应自动匹配分辨率', () async {
      final service = GalleryGenerationQueueService();
      // 1024x1024 应该匹配 1024x1024
      final post = DanbooruPost(id: 123, tagString: '1girl', width: 1024, height: 1024);
      service.addToQueue(post);

      final params = await service.processQueueItem(0);

      expect(params.width, 1024);
      expect(params.height, 1024);
    });

    test('processQueueItem 越界索引应抛出异常', () async {
      final service = GalleryGenerationQueueService();
      service.addToQueue(DanbooruPost(id: 1, tagString: '1girl'));

      expect(() => service.processQueueItem(5), throwsArgumentError);
    });
  });
}
