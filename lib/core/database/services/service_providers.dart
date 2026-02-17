import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../connection_pool_holder.dart';
import '../datasources/cooccurrence_data_source.dart';
import '../datasources/danbooru_tag_datasource_v2.dart';
import '../datasources/translation_data_source.dart';
import 'cooccurrence_service.dart';
import 'completion_service.dart';
import 'translation_service.dart';

part 'service_providers.g.dart';

/// DanbooruTag DataSource V2 Provider
@Riverpod(keepAlive: true)
Future<DanbooruTagDataSourceV2> danbooruTagDataSourceV2(Ref ref) async {
  final dataSource = DanbooruTagDataSourceV2();
  await dataSource.initialize();
  return dataSource;
}

/// Translation DataSource Provider
@Riverpod(keepAlive: true)
Future<TranslationDataSource> translationDataSource(Ref ref) async {
  final dataSource = TranslationDataSource();

  // 设置连接池，让数据源在需要时获取连接，而不是长期持有
  dataSource.setConnectionPool(ConnectionPoolHolder.instance);
  await dataSource.initialize();

  return dataSource;
}

/// Cooccurrence DataSource Provider
@Riverpod(keepAlive: true)
Future<CooccurrenceDataSource> cooccurrenceDataSource(Ref ref) async {
  final dataSource = CooccurrenceDataSource();

  // 设置连接池，让数据源在需要时获取连接，而不是长期持有
  dataSource.setConnectionPool(ConnectionPoolHolder.instance);
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
  final tagDataSource = await ref.watch(danbooruTagDataSourceV2Provider.future);
  final translationDataSource = await ref.watch(translationDataSourceProvider.future);
  return CompletionService(tagDataSource, translationDataSource);
}
