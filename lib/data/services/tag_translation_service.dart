import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/translation/translation_data_source.dart';
import '../../core/services/translation/translation_providers.dart';
import '../../core/services/translation/unified_translation_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/tag_normalizer.dart';

part 'tag_translation_service.g.dart';

/// 标签翻译服务
///
/// 这是 [UnifiedTranslationService] 的包装器，提供向后兼容的 API。
/// 所有实际翻译功能都委托给 [UnifiedTranslationService]。
class TagTranslationService {
  final UnifiedTranslationService _unifiedService;

  TagTranslationService(this._unifiedService);

  bool get isLoaded => _unifiedService.isInitialized;

  /// 加载翻译数据（现在只是等待统一服务初始化）
  Future<void> load() async {
    if (!_unifiedService.isInitialized) {
      await _unifiedService.initialize();
    }
  }

  /// 加载翻译数据（别名，保持向后兼容）
  Future<void> loadNew() async => load();

  /// 获取标签翻译
  ///
  /// [tag] 英文标签
  /// [isCharacter] 是否为角色标签（此参数现在被忽略，统一处理）
  /// 返回中文翻译，如果没有翻译则返回 null
  Future<String?> translate(String tag, {bool isCharacter = false}) async {
    final normalizedTag = TagNormalizer.normalize(tag);
    return _unifiedService.getTranslation(normalizedTag);
  }

  /// 获取角色翻译
  Future<String?> translateCharacter(String tag) async {
    final normalizedTag = TagNormalizer.normalize(tag);
    return _unifiedService.getTranslation(normalizedTag);
  }

  /// 获取通用标签翻译
  Future<String?> translateTag(String tag) async {
    final normalizedTag = TagNormalizer.normalize(tag);
    return _unifiedService.getTranslation(normalizedTag);
  }

  /// 同步获取通用标签翻译（仅访问已加载的内存数据）
  ///
  /// 注意：由于底层使用 SQLite，同步方法只能检查热缓存
  String? translateTagSync(String tag) {
    final normalizedTag = TagNormalizer.normalize(tag);
    return _unifiedService.getTranslationFromCache(normalizedTag);
  }

  /// 同步获取角色翻译（仅访问已加载的内存数据）
  String? translateCharacterSync(String tag) {
    // 角色翻译现在与标签翻译统一处理
    return translateTagSync(tag);
  }

  /// 通过中文查找英文标签
  ///
  /// [chinese] 中文翻译
  /// 返回匹配的英文标签列表
  List<String> findTagsByChinese(String chinese) {
    // 这是一个同步方法，但底层数据库查询是异步的
    // 返回空列表，建议使用 searchByChineseTranslation
    AppLogger.w(
      'findTagsByChinese is deprecated, use searchByChineseTranslation instead',
      'TagTranslation',
    );
    return [];
  }

  /// 模糊搜索中文翻译
  ///
  /// [query] 搜索词
  /// [limit] 最大返回数量
  /// 返回 Map<英文标签, 中文翻译>
  Map<String, String> searchByChineseTranslation(
    String query, {
    int limit = 20,
  }) {
    // 同步版本：返回空结果，建议使用异步版本
    // 由于这是一个同步方法，我们无法直接查询数据库
    // 触发异步搜索并记录警告
    AppLogger.w(
      'searchByChineseTranslation (sync) is deprecated, '
      'use UnifiedTranslationService.searchTranslations instead',
      'TagTranslation',
    );

    // 尝试从热缓存中搜索
    final results = <String, String>{};

    return results;
  }

  /// 异步搜索中文翻译（推荐）
  Future<Map<String, String>> searchByChineseTranslationAsync(
    String query, {
    int limit = 20,
  }) async {
    final matches = await _unifiedService.searchTranslations(
      query,
      limit: limit,
      matchTag: false,
      matchTranslation: true,
    );

    return {for (final match in matches) match.tag: match.translation};
  }

  /// 批量翻译标签
  ///
  /// 返回 Map<原始标签, 翻译>（只包含有翻译的标签）
  Future<Map<String, String>> translateBatch(
    List<String> tags, {
    bool isCharacter = false,
  }) async {
    return _unifiedService.getTranslations(tags);
  }

  /// 获取带翻译的标签显示文本
  ///
  /// 如果有翻译，返回 "英文 (中文)"
  /// 如果没有翻译，返回原始标签（下划线替换为空格）
  Future<String> getDisplayText(String tag, {bool isCharacter = false}) async {
    final translation = await translate(tag, isCharacter: isCharacter);
    final displayTag = tag.replaceAll('_', ' ');

    if (translation != null) {
      return '$displayTag ($translation)';
    }
    return displayTag;
  }

  /// 获取翻译数量
  Future<int> get translationCount async => _unifiedService.getTranslationCount();

  /// 检查是否有某个标签的翻译
  Future<bool> hasTranslation(String tag) async {
    return await translate(tag) != null;
  }
}

/// TagTranslationService Provider
///
/// 现在返回一个包装器，底层使用 UnifiedTranslationService
@Riverpod(keepAlive: true)
TagTranslationService tagTranslationService(Ref ref) {
  // 获取已初始化的统一翻译服务
  final unifiedServiceAsync = ref.watch(unifiedTranslationServiceProvider);

  return unifiedServiceAsync.when(
    data: (unifiedService) => TagTranslationService(unifiedService),
    loading: () {
      // 服务还在加载中，返回一个未初始化的服务
      // 实际调用时会等待初始化
      AppLogger.d('UnifiedTranslationService not ready yet', 'TagTranslation');
      return TagTranslationService(
        UnifiedTranslationService(dataSources: PredefinedDataSources.all),
      );
    },
    error: (error, stack) {
      AppLogger.e('Failed to get UnifiedTranslationService', error, stack, 'TagTranslation');
      // 返回一个使用默认配置的服务
      return TagTranslationService(
        UnifiedTranslationService(dataSources: PredefinedDataSources.all),
      );
    },
  );
}
