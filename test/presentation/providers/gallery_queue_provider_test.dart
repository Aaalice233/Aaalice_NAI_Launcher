import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/providers/gallery_queue_provider.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';

void main() {
  group('GalleryQueueNotifier', () {
    test('sendToHome 应添加到队列', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final posts = [
        DanbooruPost(id: 1, tagString: '1girl', width: 1024, height: 1024),
        DanbooruPost(id: 2, tagString: 'blue_hair', width: 1024, height: 1024),
      ];

      await container.read(galleryQueueNotifierProvider.notifier).sendToHome(posts);

      expect(container.read(galleryQueueNotifierProvider.notifier).queueLength, 2);
    });

    test('sendToHome 空列表不应添加', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(galleryQueueNotifierProvider.notifier).sendToHome([]);

      expect(container.read(galleryQueueNotifierProvider.notifier).queueLength, 0);
    });
  });
}
