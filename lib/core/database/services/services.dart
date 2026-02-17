/// 数据库服务层导出文件
///
/// 提供基于 DataSource 的高级服务接口，用于标签翻译、
/// 共现推荐和标签补全等功能。
///
/// 使用示例：
/// ```dart
/// import 'package:nai_launcher/core/database/services/services.dart';
///
/// // 获取服务实例（通过 Riverpod）
/// final translationService = ref.watch(translationServiceProvider);
/// final cooccurrenceService = ref.watch(cooccurrenceServiceProvider);
/// final completionService = ref.watch(completionServiceProvider);
///
/// // 使用翻译服务
/// final translation = await translationService.translate('1girl');
///
/// // 使用共现服务
/// final recommendations = await cooccurrenceService.getRecommendations(['1girl']);
///
/// // 使用补全服务
/// final completions = await completionService.complete('long_');
/// ```
library;

export 'completion_service.dart'
    show
        CompletionService,
        CompletionResult;

export 'cooccurrence_service.dart'
    show
        CooccurrenceService,
        Recommendation;

export 'translation_service.dart'
    show
        TranslationService;
