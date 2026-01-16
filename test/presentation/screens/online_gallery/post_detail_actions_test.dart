import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/gallery_prompt_service.dart';

void main() {
  group('PostDetail Actions', () {
    test('GalleryPromptService 应支持详情页提示词操作', () {
      final service = GalleryPromptService();
      final post = DanbooruPost(id: 123, tagString: '1girl blue_hair solo');

      // 验证可以获取提示词
      final rawTags = service.toRawTags(post);
      expect(rawTags, '1girl, blue_hair, solo');

      // 验证可以转换 NAI 格式
      final naiFormat = service.toNaiFormat(post.tags);
      expect(naiFormat, '1girl, blue_hair, solo');
    });

    test('DanbooruPost.tags 应返回标签列表', () {
      final post = DanbooruPost(id: 123, tagString: '1girl blue_hair solo');

      expect(post.tags, equals(['1girl', 'blue_hair', 'solo']));
    });
  });
}
