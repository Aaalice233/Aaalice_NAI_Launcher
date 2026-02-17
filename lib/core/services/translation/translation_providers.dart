import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 从新的数据源导出 TranslationMatch
export '../../database/datasources/translation_data_source.dart' show TranslationMatch;

import '../../database/datasources/translation_data_source.dart' as new_ds;
import 'translation_data_source.dart';
import 'unified_translation_service.dart';

part 'translation_providers.g.dart';

/// 统一翻译服务 Provider
///
/// 应用启动时自动初始化，合并多个数据源的翻译
@Riverpod(keepAlive: true)
Future<UnifiedTranslationService> unifiedTranslationService(Ref ref) async {
  final service = UnifiedTranslationService(
    dataSources: PredefinedDataSources.all,
  );

  // 等待初始化完成
  await service.initialize();

  return service;
}

/// 翻译查询 Provider（用于监听特定标签的翻译）
///
/// 使用示例：
/// ```dart
/// final translation = ref.watch(translationProvider('simple_background'));
/// ```
@riverpod
Future<String?> tagTranslation(Ref ref, String tag) async {
  final service = await ref.watch(unifiedTranslationServiceProvider.future);
  return service.getTranslation(tag);
}

/// 批量翻译查询 Provider
@riverpod
Future<Map<String, String>> tagTranslations(Ref ref, List<String> tags) async {
  final service = await ref.watch(unifiedTranslationServiceProvider.future);
  return service.getTranslations(tags);
}

/// 翻译服务初始化状态 Provider
@Riverpod(keepAlive: true)
Stream<double> translationInitProgress(Ref ref) async* {
  // TODO: 实现进度报告
  yield 1.0;
}

/// 数据源统计信息 Provider
@riverpod
Future<Map<String, DataSourceStats>> translationDataSourceStats(Ref ref) async {
  final service = await ref.watch(unifiedTranslationServiceProvider.future);
  return service.stats;
}

/// 翻译搜索 Provider
@riverpod
Future<List<new_ds.TranslationMatch>> searchTranslations(
  Ref ref, {
  required String query,
  int limit = 20,
}) async {
  final service = await ref.watch(unifiedTranslationServiceProvider.future);
  return service.searchTranslations(query, limit: limit);
}
