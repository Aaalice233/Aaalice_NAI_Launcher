import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../autocomplete/cooccurrence_data_pack_provider.dart';
import '../../services/desktop_app_shutdown_service.dart';
import '../../utils/app_logger.dart';
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
TranslationDataSource translationDataSource(Ref ref) {
  final source = TranslationDataSource();
  final unregister = DesktopAppShutdownService.addCleanupHandler(
    source.dispose,
  );
  ref.onDispose(() {
    unregister();
    unawaited(source.dispose());
  });
  return source;
}

/// Cooccurrence DataSource Provider
@Riverpod(keepAlive: true)
Future<CooccurrenceDataSource> cooccurrenceDataSource(Ref ref) async {
  final dataPack = ref.watch(cooccurrenceDataPackServiceProvider.notifier);
  await dataPack.initialize();
  final dataSource = CooccurrenceDataSource(dataPackService: dataPack);
  await dataSource.initialize();
  ref.onDispose(dataSource.dispose);
  return dataSource;
}

/// 翻译服务 Provider
@Riverpod(keepAlive: true)
Future<TranslationService> translationService(Ref ref) async {
  final dataSource = ref.watch(translationDataSourceProvider);
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
  final translationDataSource = ref.watch(translationDataSourceProvider);
  return CompletionService(tagDataSource, translationDataSource);
}
