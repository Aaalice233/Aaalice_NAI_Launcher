import '../../utils/app_logger.dart';
import '../datasources/translation_data_source.dart';

/// 翻译服务
///
/// 提供标签翻译功能的高级服务层，封装 TranslationDataSource 的底层操作。
/// 支持单个翻译查询和批量翻译查询。
class TranslationService {
  final TranslationDataSource _dataSource;

  TranslationService(this._dataSource);

  /// 翻译单个标签
  ///
  /// [enTag] 英文标签名
  /// 返回对应的中文翻译，如果没有找到则返回 null
  Future<String?> translate(String enTag) async {
    if (enTag.isEmpty) {
      return null;
    }

    try {
      final result = await _dataSource.query(enTag);
      AppLogger.d('Translated "$enTag" → "$result"', 'TranslationService');
      return result;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to translate "$enTag"',
        e,
        stack,
        'TranslationService',
      );
      return null;
    }
  }

  /// 批量翻译标签
  ///
  /// [tags] 英文标签名列表
  /// 返回 Map<英文标签, 中文翻译>，只包含找到翻译的标签
  Future<Map<String, String>> translateBatch(List<String> tags) async {
    if (tags.isEmpty) {
      return {};
    }

    try {
      final results = await _dataSource.queryBatch(tags);
      AppLogger.d(
        'Batch translated ${tags.length} tags, found ${results.length}',
        'TranslationService',
      );
      return results;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to batch translate ${tags.length} tags',
        e,
        stack,
        'TranslationService',
      );
      return {};
    }
  }

  /// 搜索翻译
  ///
  /// [query] 搜索关键词（支持英文标签名或中文翻译的部分匹配）
  /// [limit] 返回结果数量限制
  /// [matchTag] 是否匹配标签名
  /// [matchTranslation] 是否匹配翻译文本
  Future<List<TranslationMatch>> search(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final results = await _dataSource.search(
        query,
        limit: limit,
        matchTag: matchTag,
        matchTranslation: matchTranslation,
      );
      AppLogger.d(
        'Search "$query" found ${results.length} results',
        'TranslationService',
      );
      return results;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to search translations for "$query"',
        e,
        stack,
        'TranslationService',
      );
      return [];
    }
  }

  /// 获取翻译总数
  Future<int> getCount() async {
    try {
      return await _dataSource.getCount();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get translation count',
        e,
        stack,
        'TranslationService',
      );
      return 0;
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() {
    return _dataSource.getCacheStatistics();
  }
}
