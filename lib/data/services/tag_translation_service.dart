import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';

part 'tag_translation_service.g.dart';

/// 标签翻译服务
///
/// 提供 Danbooru 标签的中文翻译功能
/// 数据来源: ComfyUI-Danbooru-Gallery 项目
class TagTranslationService {
  /// 通用标签翻译表 (英文 -> 中文)
  final Map<String, String> _tagTranslations = {};

  /// 角色名翻译表 (英文 -> 中文)
  final Map<String, String> _characterTranslations = {};

  bool _isLoaded = false;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 加载翻译数据
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      await Future.wait([
        _loadTagTranslations(),
        _loadCharacterTranslations(),
      ]);
      _isLoaded = true;
      AppLogger.i(
        'Tag translations loaded: ${_tagTranslations.length} tags, ${_characterTranslations.length} characters',
        'TagTranslation',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to load tag translations', e, stack, 'TagTranslation');
    }
  }

  /// 加载通用标签翻译
  Future<void> _loadTagTranslations() async {
    try {
      final csvData = await rootBundle.loadString('assets/translations/danbooru.csv');
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // 格式: 英文标签,中文翻译
        final parts = line.split(',');
        if (parts.length >= 2) {
          final englishTag = parts[0].trim().toLowerCase();
          final chineseTranslation = parts.sublist(1).join(',').trim();
          if (englishTag.isNotEmpty && chineseTranslation.isNotEmpty) {
            _tagTranslations[englishTag] = chineseTranslation;
          }
        }
      }
    } catch (e) {
      AppLogger.w('Failed to load danbooru.csv: $e', 'TagTranslation');
    }
  }

  /// 加载角色名翻译
  Future<void> _loadCharacterTranslations() async {
    try {
      final csvData = await rootBundle.loadString('assets/translations/wai_characters.csv');
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // 格式: 中文名称,英文标签
        final parts = line.split(',');
        if (parts.length >= 2) {
          final chineseName = parts[0].trim();
          final englishTag = parts.sublist(1).join(',').trim().toLowerCase();
          if (englishTag.isNotEmpty && chineseName.isNotEmpty) {
            _characterTranslations[englishTag] = chineseName;
          }
        }
      }
    } catch (e) {
      AppLogger.w('Failed to load wai_characters.csv: $e', 'TagTranslation');
    }
  }

  /// 获取标签翻译
  ///
  /// [tag] 英文标签
  /// [isCharacter] 是否为角色标签（优先查找角色翻译表）
  /// 返回中文翻译，如果没有翻译则返回 null
  String? translate(String tag, {bool isCharacter = false}) {
    final normalizedTag = tag.trim().toLowerCase();

    // 角色标签优先查找角色翻译表
    if (isCharacter) {
      final characterTranslation = _characterTranslations[normalizedTag];
      if (characterTranslation != null) return characterTranslation;
    }

    // 查找通用翻译表
    return _tagTranslations[normalizedTag];
  }

  /// 获取角色翻译
  String? translateCharacter(String tag) {
    return _characterTranslations[tag.trim().toLowerCase()];
  }

  /// 获取通用标签翻译
  String? translateTag(String tag) {
    return _tagTranslations[tag.trim().toLowerCase()];
  }

  /// 批量翻译标签
  ///
  /// 返回 Map<原始标签, 翻译>（只包含有翻译的标签）
  Map<String, String> translateBatch(List<String> tags, {bool isCharacter = false}) {
    final result = <String, String>{};
    for (final tag in tags) {
      final translation = translate(tag, isCharacter: isCharacter);
      if (translation != null) {
        result[tag] = translation;
      }
    }
    return result;
  }

  /// 获取带翻译的标签显示文本
  ///
  /// 如果有翻译，返回 "英文 (中文)"
  /// 如果没有翻译，返回原始标签（下划线替换为空格）
  String getDisplayText(String tag, {bool isCharacter = false}) {
    final translation = translate(tag, isCharacter: isCharacter);
    final displayTag = tag.replaceAll('_', ' ');

    if (translation != null) {
      return '$displayTag ($translation)';
    }
    return displayTag;
  }
}

/// TagTranslationService Provider
@Riverpod(keepAlive: true)
TagTranslationService tagTranslationService(TagTranslationServiceRef ref) {
  final service = TagTranslationService();
  // 异步加载翻译数据
  service.load();
  return service;
}

