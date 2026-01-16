import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/gallery_prompt_service.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';

void main() {
  group('GalleryPromptService', () {
    test('toNaiFormat 应转换标签为 NAI 格式', () {
      final service = GalleryPromptService();
      final result = service.toNaiFormat(['1girl', 'blue_hair', 'solo']);

      expect(result, '1girl, blue_hair, solo');
    });

    test('stripMetaTags 应移除元标签', () {
      final service = GalleryPromptService();
      final tags = ['1girl', 'blue_hair', 'solo', 'highres', 'official_art'];
      final result = service.stripMetaTags(tags);

      expect(result, equals(['1girl', 'blue_hair', 'solo']));
    });

    test('stripMetaTags 不应移除通用标签', () {
      final service = GalleryPromptService();
      final tags = ['1girl', 'blue_eyes', 'long_hair', 'highres'];
      final result = service.stripMetaTags(tags);

      expect(result, equals(['1girl', 'blue_eyes', 'long_hair']));
    });

    test('toRawTags 应返回原始标签字符串', () {
      final service = GalleryPromptService();
      final post = DanbooruPost(id: 123, tagString: '1girl blue_hair solo');
      final result = service.toRawTags(post);

      expect(result, '1girl, blue_hair, solo');
    });

    test('toRawTags 处理空标签', () {
      final service = GalleryPromptService();
      final post = DanbooruPost(id: 123, tagString: '');
      final result = service.toRawTags(post);

      expect(result, '');
    });

    test('getAllTags 应返回所有标签列表', () {
      final service = GalleryPromptService();
      final post = DanbooruPost(id: 123, tagString: '1girl blue_hair solo');
      final result = service.getAllTags(post);

      expect(result, equals(['1girl', 'blue_hair', 'solo']));
    });

    test('toNaiFormat 处理大小写敏感的元标签', () {
      final service = GalleryPromptService();
      final tags = ['1girl', 'HIGHRES', 'Official_Art', 'best_quality'];
      final result = service.toNaiFormat(tags);

      // 应该移除所有元标签
      expect(result, '1girl');
    });
  });
}
