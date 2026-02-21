/// 统一翻译服务导出文件
///
/// 使用示例：
/// ```dart
/// import 'package:nai_launcher/core/services/translation/translation_service.dart';
///
/// // 获取翻译
/// final translation = ref.watch(tagTranslationProvider('simple_background'));
///
/// // 批量获取
/// final translations = ref.watch(tagTranslationsProvider(['1girl', 'solo']));
///
/// // 搜索
/// final results = ref.watch(searchTranslationsProvider(query: '背景'));
/// ```
library;

export '../../database/datasources/translation_data_source.dart' show TranslationMatch;

export 'unified_translation_service.dart' show UnifiedTranslationService;

export 'translation_providers.dart'
    show
        unifiedTranslationServiceProvider,
        tagTranslationProvider,
        tagTranslationsProvider,
        searchTranslationsProvider;
