import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../utils/app_logger.dart';
import '../database_providers.dart';
import '../datasources/cooccurrence_data_source.dart';
import '../datasources/danbooru_tag_data_source.dart';
import '../datasources/translation_data_source.dart';
import 'cooccurrence_service.dart';
import 'completion_service.dart';
import 'translation_service.dart';

part 'service_providers.g.dart';

/// DanbooruTag DataSource Provider
@Riverpod(keepAlive: true)
Future<DanbooruTagDataSource> danbooruTagDataSource(Ref ref) async {
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagDataSourceProvider BUILD START',
    'DanbooruTagDataSource',
  );
  final dataSource = DanbooruTagDataSource();
  await dataSource.initialize();
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagDataSourceProvider BUILD END - hash=${dataSource.hashCode}',
    'DanbooruTagDataSource',
  );
  return dataSource;
}

/// Translation DataSource Provider
@Riverpod(keepAlive: true)
Future<TranslationDataSource> translationDataSource(Ref ref) async {
  // 等待数据库管理器就绪
  await ref.watch(databaseManagerProvider.future);

  final dataSource = TranslationDataSource();

  // 数据源通过 ConnectionPoolHolder 在需要时动态获取连接
  await dataSource.initialize();

  return dataSource;
}

/// Cooccurrence DataSource Provider
@Riverpod(keepAlive: true)
Future<CooccurrenceDataSource> cooccurrenceDataSource(Ref ref) async {
  // 等待数据库管理器就绪
  await ref.watch(databaseManagerProvider.future);

  final dataSource = CooccurrenceDataSource();

  // 数据源通过 ConnectionPoolHolder 在需要时动态获取连接
  await dataSource.initialize();

  return dataSource;
}

/// 翻译服务 Provider
@Riverpod(keepAlive: true)
Future<TranslationService> translationService(Ref ref) async {
  final dataSource = await ref.watch(translationDataSourceProvider.future);
  return TranslationService(dataSource);
}

/// 共现服务 Provider
@Riverpod(keepAlive: true)
Future<CooccurrenceService> cooccurrenceService(Ref ref) async {
  final dataSource = await ref.watch(cooccurrenceDataSourceProvider.future);
  return CooccurrenceService(dataSource);
}

/// 补全服务 Provider
@Riverpod(keepAlive: true)
Future<CompletionService> completionService(Ref ref) async {
  final tagDataSource = await ref.watch(danbooruTagDataSourceProvider.future);
  final translationDataSource = await ref.watch(translationDataSourceProvider.future);
  return CompletionService(tagDataSource, translationDataSource);
}
