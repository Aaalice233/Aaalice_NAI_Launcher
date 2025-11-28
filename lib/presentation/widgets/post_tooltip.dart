import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/services/tag_translation_service.dart';

/// 帖子悬浮提示组件
///
/// 显示帖子的详细信息，包括：
/// - 基本信息：尺寸、分数、收藏数、上传时间
/// - 分类标签：艺术家、角色、作品、通用标签（带中文翻译）
class PostTooltip extends ConsumerWidget {
  final DanbooruPost post;
  final Widget child;

  const PostTooltip({
    super.key,
    required this.post,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationService = ref.watch(tagTranslationServiceProvider);

    return Tooltip(
      richMessage: _buildTooltipContent(context, translationService),
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 10),
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  TextSpan _buildTooltipContent(BuildContext context, TagTranslationService translationService) {
    final List<InlineSpan> spans = [];

    // 基本信息
    spans.add(const TextSpan(
      text: '📐 ',
      style: TextStyle(fontSize: 13),
    ));
    spans.add(TextSpan(
      text: '${post.width}×${post.height}',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ));
    spans.add(const TextSpan(text: '  '));

    spans.add(const TextSpan(
      text: '⬆ ',
      style: TextStyle(fontSize: 13),
    ));
    spans.add(TextSpan(
      text: '${post.score}',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ));
    spans.add(const TextSpan(text: '  '));

    spans.add(const TextSpan(
      text: '❤ ',
      style: TextStyle(fontSize: 13),
    ));
    spans.add(TextSpan(
      text: '${post.favCount}',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ));

    // 上传时间
    if (post.createdAt != null) {
      try {
        final date = DateTime.parse(post.createdAt!);
        spans.add(const TextSpan(text: '\n'));
        spans.add(const TextSpan(
          text: '📅 ',
          style: TextStyle(fontSize: 13),
        ));
        spans.add(TextSpan(
          text: DateFormat('yyyy-MM-dd').format(date),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ));
      } catch (_) {}
    }

    // 艺术家
    if (post.artistTags.isNotEmpty) {
      spans.add(const TextSpan(text: '\n\n'));
      spans.add(const TextSpan(
        text: '🎨 艺术家\n',
        style: TextStyle(
          color: Color(0xFFFF8A8A),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ));
      final artistTexts = post.artistTags.take(3).map((t) {
        final translation = translationService.translateTag(t);
        final display = t.replaceAll('_', ' ');
        return translation != null ? '$display ($translation)' : display;
      }).join(', ');
      spans.add(TextSpan(
        text: artistTexts,
        style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 11),
      ));
    }

    // 角色
    if (post.characterTags.isNotEmpty) {
      spans.add(const TextSpan(text: '\n\n'));
      spans.add(const TextSpan(
        text: '👤 角色\n',
        style: TextStyle(
          color: Color(0xFF8AFF8A),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ));
      final charTexts = post.characterTags.take(5).map((t) {
        final translation = translationService.translate(t, isCharacter: true);
        final display = t.replaceAll('_', ' ');
        return translation != null ? '$display ($translation)' : display;
      }).join(', ');
      spans.add(TextSpan(
        text: charTexts,
        style: const TextStyle(color: Color(0xFF8AFF8A), fontSize: 11),
      ));
      if (post.characterTags.length > 5) {
        spans.add(TextSpan(
          text: ' +${post.characterTags.length - 5}',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ));
      }
    }

    // 作品
    if (post.copyrightTags.isNotEmpty) {
      spans.add(const TextSpan(text: '\n\n'));
      spans.add(const TextSpan(
        text: '📺 作品\n',
        style: TextStyle(
          color: Color(0xFFCC8AFF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ));
      final copyrightTexts = post.copyrightTags.take(3).map((t) {
        final translation = translationService.translateTag(t);
        final display = t.replaceAll('_', ' ');
        return translation != null ? '$display ($translation)' : display;
      }).join(', ');
      spans.add(TextSpan(
        text: copyrightTexts,
        style: const TextStyle(color: Color(0xFFCC8AFF), fontSize: 11),
      ));
    }

    // 通用标签（只显示前几个重要的）
    if (post.generalTags.isNotEmpty) {
      spans.add(const TextSpan(text: '\n\n'));
      spans.add(const TextSpan(
        text: '🏷 标签\n',
        style: TextStyle(
          color: Color(0xFF8AC8FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ));
      final tagTexts = post.generalTags.take(8).map((t) {
        final translation = translationService.translateTag(t);
        final display = t.replaceAll('_', ' ');
        return translation != null ? '$display ($translation)' : display;
      }).join(', ');
      spans.add(TextSpan(
        text: tagTexts,
        style: const TextStyle(color: Color(0xFF8AC8FF), fontSize: 11),
      ));
      if (post.generalTags.length > 8) {
        spans.add(TextSpan(
          text: ' +${post.generalTags.length - 8}',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ));
      }
    }

    return TextSpan(children: spans);
  }
}
