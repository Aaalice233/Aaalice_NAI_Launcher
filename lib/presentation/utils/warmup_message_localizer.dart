import '../../l10n/app_localizations.dart';

class WarmupMessageLocalizer {
  const WarmupMessageLocalizer._();

  static String localizeTask(AppLocalizations l10n, String taskKey) {
    final message = _localizeKnownMessage(l10n, taskKey);
    if (message != null) {
      return message;
    }

    if (taskKey == 'complete') {
      return l10n.warmup_complete;
    }

    return taskKey;
  }

  static String localizeSubTask(AppLocalizations l10n, String message) {
    final localized = _localizeKnownMessage(l10n, message);
    return localized ?? message;
  }

  static String? _localizeKnownMessage(AppLocalizations l10n, String message) {
    if (message.startsWith('warmup_networkCheck_attempt|')) {
      final parts = message.split('|');
      if (parts.length == 3) {
        return l10n.warmup_networkCheck_attempt(parts[1], parts[2]);
      }
      return l10n.warmup_networkCheck_testing;
    }

    if (message.startsWith('warmup_networkCheck_success|')) {
      final parts = message.split('|');
      return l10n.warmup_networkCheck_success(
        parts.length == 2 ? parts[1] : '',
      );
    }

    if (message.startsWith('warmup_fetchingTags|')) {
      final parts = message.split('|');
      return l10n.warmup_fetchingTags(parts.length == 2 ? parts[1] : '');
    }

    return switch (message) {
      'warmup_preparing' => l10n.warmup_preparing,
      'warmup_complete' => l10n.warmup_complete,
      'warmup_networkCheck' => l10n.warmup_networkCheck,
      'warmup_networkCheck_noProxy' => l10n.warmup_networkCheck_noProxy,
      'warmup_networkCheck_noSystemProxy' =>
        l10n.warmup_networkCheck_noSystemProxy,
      'warmup_networkCheck_manualIncomplete' =>
        l10n.warmup_networkCheck_manualIncomplete,
      'warmup_networkCheck_testing' => l10n.warmup_networkCheck_testing,
      'warmup_networkCheck_testingProxy' =>
        l10n.warmup_networkCheck_testingProxy,
      'warmup_networkCheck_timeout' => l10n.warmup_networkCheck_timeout,
      'warmup_dataMigration' => l10n.warmup_dataMigration,
      'warmup_loadingTranslation' => l10n.warmup_loadingTranslation,
      'warmup_initTagSystem' => l10n.warmup_initTagSystem,
      'warmup_initUnifiedDatabase' => l10n.warmup_initUnifiedDatabase,
      'warmup_loadingPromptConfig' => l10n.warmup_loadingPromptConfig,
      'warmup_danbooruAuth' => l10n.warmup_danbooruAuth,
      'warmup_imageEditor' => l10n.warmup_imageEditor,
      'warmup_database' => l10n.warmup_database,
      'warmup_network' => l10n.warmup_network,
      'warmup_fonts' => l10n.warmup_fonts,
      'warmup_imageCache' => l10n.warmup_imageCache,
      'warmup_statistics' => l10n.warmup_statistics,
      'warmup_artistsSync' => l10n.warmup_artistsSync,
      'warmup_subscription' => l10n.warmup_subscription,
      'warmup_dataSourceCache' => l10n.warmup_dataSourceCache,
      'warmup_galleryFileCount' => l10n.warmup_galleryFileCount,
      'warmup_cooccurrenceData' => l10n.warmup_cooccurrenceData,
      'warmup_cooccurrenceInit' => l10n.warmup_cooccurrenceInit,
      'warmup_danbooruTagsInit' => l10n.warmup_danbooruTagsInit,
      'warmup_galleryDataSource' => l10n.warmup_galleryDataSource,
      'warmup_checkAndRecoverData' => l10n.warmup_checkAndRecoverData,
      'warmup_translationInit' => l10n.warmup_translationInit,
      'warmup_group_dataSourceInitialization' =>
        l10n.warmup_group_dataSourceInitialization,
      'warmup_group_dataSourceInitialization_complete' =>
        l10n.warmup_group_dataSourceInitialization_complete,
      'warmup_group_basicUI' => l10n.warmup_group_basicUI,
      'warmup_group_basicUI_complete' => l10n.warmup_group_basicUI_complete,
      'warmup_group_dataServices' => l10n.warmup_group_dataServices,
      'warmup_group_dataServices_complete' =>
        l10n.warmup_group_dataServices_complete,
      'warmup_group_networkServices' => l10n.warmup_group_networkServices,
      'warmup_group_networkServices_complete' =>
        l10n.warmup_group_networkServices_complete,
      'warmup_group_cacheServices' => l10n.warmup_group_cacheServices,
      'warmup_group_cacheServices_complete' =>
        l10n.warmup_group_cacheServices_complete,
      'warmup_fetchingTagDataFromServer' =>
        l10n.warmup_fetchingTagDataFromServer,
      'warmup_fetchingGeneralTags' => l10n.warmup_fetchingGeneralTags,
      'warmup_fetchingCharacterTags' => l10n.warmup_fetchingCharacterTags,
      'warmup_fetchingCopyrightTags' => l10n.warmup_fetchingCopyrightTags,
      'warmup_fetchingMetaTags' => l10n.warmup_fetchingMetaTags,
      _ => null,
    };
  }
}
