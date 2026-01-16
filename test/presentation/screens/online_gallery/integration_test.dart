import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/gallery_prompt_service.dart';
import 'package:nai_launcher/data/services/resolution_matcher.dart';
import 'package:nai_launcher/data/services/gallery_generation_queue_service.dart';
import 'package:nai_launcher/presentation/providers/gallery_multi_select_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_queue_provider.dart';

void main() {
  group('Gallery Integration Tests', () {
    test('完整多选流程测试', () {
      // 1. 创建 Provider 容器
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 2. 测试多选状态管理
      final multiSelectNotifier = container.read(multiSelectNotifierProvider.notifier);

      // 初始状态
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, isEmpty);
      expect(container.read(multiSelectNotifierProvider).isSelectionMode, isFalse);

      // 选中第一张
      multiSelectNotifier.toggleSelection(1);
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, contains(1));
      expect(container.read(multiSelectNotifierProvider).isSelectionMode, isTrue);

      // 选中第二张
      multiSelectNotifier.toggleSelection(2);
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, contains(2));
      expect(container.read(multiSelectNotifierProvider).selectedPostIds.length, 2);

      // 取消选中第一张
      multiSelectNotifier.toggleSelection(1);
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, isNot(contains(1)));
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, contains(2));

      // 清除选择
      multiSelectNotifier.clearSelection();
      expect(container.read(multiSelectNotifierProvider).selectedPostIds, isEmpty);
      expect(container.read(multiSelectNotifierProvider).isSelectionMode, isFalse);
    });

    test('提示词转换流程测试', () {
      final service = GalleryPromptService();

      // 验证标签转换
      final post = DanbooruPost(id: 123, tagString: '1girl blue_hair solo');
      expect(service.toRawTags(post), '1girl, blue_hair, solo');
      expect(service.toNaiFormat(post.tags), '1girl, blue_hair, solo');
    });

    test('分辨率匹配流程测试', () {
      final matcher = ResolutionMatcher();

      // 验证各种分辨率匹配
      expect(matcher.matchBestResolution(1024, 1024).width, 1024);
      expect(matcher.matchBestResolution(1024, 1024).height, 1024);

      expect(matcher.matchBestResolution(1024, 2048).width < matcher.matchBestResolution(1024, 2048).height, isTrue);
    });

    test('生成队列流程测试', () async {
      final service = GalleryGenerationQueueService();

      // 添加到队列
      final post = DanbooruPost(id: 1, tagString: '1girl', width: 1024, height: 1024);
      service.addToQueue(post);

      expect(service.length, 1);
      expect(service.isEmpty, isFalse);

      // 处理队列项
      final params = await service.processQueueItem(0);
      expect(params.prompt, contains('1girl'));
      expect(params.width, 1024);
      expect(params.height, 1024);

      // 清空队列
      service.clearQueue();
      expect(service.isEmpty, isTrue);
    });

    test('批量添加到队列测试', () async {
      final service = GalleryGenerationQueueService();
      final posts = [
        DanbooruPost(id: 1, tagString: '1girl', width: 1024, height: 1024),
        DanbooruPost(id: 2, tagString: 'blue_hair', width: 1024, height: 1024),
        DanbooruPost(id: 3, tagString: 'solo', width: 1024, height: 1024),
      ];

      service.addAllToQueue(posts);

      expect(service.length, 3);

      // 处理所有项
      for (var i = 0; i < 3; i++) {
        final params = await service.processQueueItem(0);
        expect(params.prompt, isNotEmpty);
        expect(params.width, 1024);
        expect(params.height, 1024);
        service.removeItem(0);
      }

      expect(service.isEmpty, isTrue);
    });

    test('队列服务与提示词服务集成测试', () async {
      final queueService = GalleryGenerationQueueService();
      final promptService = GalleryPromptService();

      final post = DanbooruPost(id: 1, tagString: '1girl blue_hair solo highres', width: 832, height: 1216);

      // 使用提示词服务转换后添加到队列
      final naiPrompt = promptService.toNaiFormat(post.tags);
      expect(naiPrompt, '1girl, blue_hair, solo'); // 应该过滤掉 highres

      // 验证队列处理
      queueService.addToQueue(post, format: 'nai');
      final params = await queueService.processQueueItem(0);

      expect(params.prompt, naiPrompt);
      expect(params.width, 832); // 自动匹配 832x1216
      expect(params.height, 1216);
    });
  });
}
