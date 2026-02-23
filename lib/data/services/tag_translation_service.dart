import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/datasources/translation_data_source.dart';
import '../../core/database/services/service_providers.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/tag_normalizer.dart';

part 'tag_translation_service.g.dart';

/// 标签翻译服务（数据库版）
///
/// 直接查询预构建的翻译数据库
class TagTranslationService {
  TranslationDataSource? _dataSource;

  /// 设置数据源（初始化时调用）
  void setDataSource(TranslationDataSource dataSource) {
    _dataSource = dataSource;
  }

  /// 获取标签翻译
  ///
  /// [tag] 英文标签
  /// 返回中文翻译，如果没有翻译则返回 null
  Future<String?> translate(String tag) async {
    if (_dataSource == null) return null;
    
    final normalizedTag = TagNormalizer.normalize(tag);
    try {
      return await _dataSource!.query(normalizedTag);
    } catch (e) {
      AppLogger.w('[TagTranslation] Error querying translation: $e', 'TagTranslation');
      return null;
    }
  }

  /// 批量翻译标签
  ///
  /// 返回 Map<原始标签, 翻译>（只包含有翻译的标签）
  Future<Map<String, String>> translateBatch(List<String> tags) async {
    if (_dataSource == null) return {};
    
    final normalizedTags = tags.map(TagNormalizer.normalize).toList();
    try {
      return await _dataSource!.queryBatch(normalizedTags);
    } catch (e) {
      AppLogger.w('[TagTranslation] Error querying batch: $e', 'TagTranslation');
      return {};
    }
  }

  /// 搜索翻译
  ///
  /// [query] 搜索词
  /// [limit] 最大返回数量
  Future<List<TranslationMatch>> search(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    if (_dataSource == null) return [];
    
    try {
      return await _dataSource!.search(
        query,
        limit: limit,
        matchTag: matchTag,
        matchTranslation: matchTranslation,
      );
    } catch (e) {
      AppLogger.w('[TagTranslation] Error searching: $e', 'TagTranslation');
      return [];
    }
  }

  /// 获取翻译数量
  Future<int> get translationCount async {
    if (_dataSource == null) return 0;
    
    try {
      return await _dataSource!.getCount();
    } catch (e) {
      return 0;
    }
  }

  /// 检查是否有某个标签的翻译
  Future<bool> hasTranslation(String tag) async {
    return await translate(tag) != null;
  }
}

// 全局服务实例
final _globalTranslationService = TagTranslationService();

/// TagTranslationService Provider
///
/// 返回已初始化的服务实例
@Riverpod(keepAlive: true)
TagTranslationService tagTranslationService(Ref ref) {
  // 监听数据源初始化
  final dataSourceAsync = ref.watch(translationDataSourceProvider);
  
  dataSourceAsync.whenOrNull(
    data: (dataSource) {
      _globalTranslationService.setDataSource(dataSource);
    },
  );
  
  return _globalTranslationService;
}
