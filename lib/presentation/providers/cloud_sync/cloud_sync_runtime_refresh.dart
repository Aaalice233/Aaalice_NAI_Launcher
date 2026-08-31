import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/autocomplete/autocomplete_settings.dart' as autocomplete;
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../composition_guide_provider.dart';
import '../fixed_tags_provider.dart';
import '../font_provider.dart';
import '../font_scale_provider.dart';
import '../gallery_album_provider.dart';
import '../generation/generation_settings_notifiers.dart';
import '../history_click_behavior_provider.dart';
import '../image_save_settings_provider.dart';
import '../locale_provider.dart';
import '../notification_settings_provider.dart';
import '../online_gallery_blacklist_provider.dart';
import '../online_gallery_local_favorites_provider.dart';
import '../online_gallery_output_filter_provider.dart';
import '../online_gallery_prompt_tag_settings_provider.dart';
import '../precise_ref_library_provider.dart';
import '../preview_transparency_provider.dart';
import '../prompt_config_provider.dart';
import '../prompt_regex_rules_provider.dart';
import '../quality_preset_provider.dart';
import '../quick_tag_cloud_gallery_provider.dart';
import '../random_mode_provider.dart';
import '../random_preset_provider.dart';
import '../share_image_settings_provider.dart';
import '../shortcuts_provider.dart';
import '../tag_favorite_provider.dart';
import '../tag_library_page_provider.dart';
import '../tag_template_provider.dart';
import '../theme_provider.dart';
import '../uc_preset_provider.dart';
import '../vibe_library_category_provider.dart';
import '../vibe_library_provider.dart';
import '../watermark_settings_provider.dart';

Future<void> refreshCloudSyncRuntime(Ref ref, Set<String> adapterIds) async {
  if (adapterIds.contains('portable-settings')) {
    ref.read(fixedTagsNotifierProvider.notifier).refresh();
    ref.read(tagLibraryPageNotifierProvider.notifier).refresh();
    ref.invalidate(themeNotifierProvider);
    ref.invalidate(fontNotifierProvider);
    ref.invalidate(fontScaleNotifierProvider);
    ref.invalidate(localeNotifierProvider);
    ref.invalidate(watermarkSettingsProvider);
    ref.invalidate(historyClickBehaviorNotifierProvider);
    ref.invalidate(previewTransparencyNotifierProvider);
    ref.invalidate(compositionGuideNotifierProvider);
    ref.invalidate(notificationSettingsNotifierProvider);
    ref.invalidate(imageSaveSettingsNotifierProvider);
    ref.invalidate(shareImageSettingsProvider);
    ref.invalidate(onlineGalleryOutputFilterProvider);
    ref.invalidate(onlineGalleryPromptTagSettingsProvider);
    ref.invalidate(promptRegexRulesProvider);
    ref.invalidate(randomModeNotifierProvider);
    ref.invalidate(autocomplete.autocompleteSettingsProvider);
    ref.invalidate(autoFormatPromptSettingsProvider);
    ref.invalidate(highlightEmphasisSettingsProvider);
    ref.invalidate(sdSyntaxAutoConvertSettingsProvider);
    ref.invalidate(resolveAliasOnCopySettingsProvider);
    ref.invalidate(promptWeightScrollSettingsProvider);
    ref.invalidate(cooccurrenceSettingsProvider);
    ref.invalidate(randomPromptModeProvider);
    ref.invalidate(randomPromptToolsVisibilityProvider);
    ref.invalidate(generationStreamPreviewSettingsProvider);
    ref.invalidate(imagesPerRequestProvider);
    ref.invalidate(qualityPresetNotifierProvider);
    ref.invalidate(ucPresetNotifierProvider);
    ref.invalidate(quickTagCloudUserServiceProvider);
    ref.invalidate(quickTagCloudFilterProvider);
  }

  if (adapterIds.contains('user-tag-library')) {
    ref.read(tagLibraryPageNotifierProvider.notifier).refresh();
  }
  if (adapterIds.contains('tag-favorites')) {
    ref.read(tagFavoriteNotifierProvider.notifier).refresh();
  }
  if (adapterIds.contains('tag-templates')) {
    ref.read(tagTemplateNotifierProvider.notifier).refresh();
  }
  if (adapterIds.contains('random-presets')) {
    ref.invalidate(randomPresetNotifierProvider);
  }
  if (adapterIds.contains('prompt-presets')) {
    ref.invalidate(promptConfigNotifierProvider);
  }
  if (adapterIds.contains('shortcuts')) {
    ref.invalidate(shortcutConfigNotifierProvider);
  }
  if (adapterIds.contains('prompt-assistant-profile')) {
    ref.invalidate(promptAssistantConfigProvider);
  }
  if (adapterIds.contains('agent-system-prompt') ||
      adapterIds.contains('agent-skills')) {
    ref.invalidate(agentSettingsProvider);
  }
  if (adapterIds.contains('gallery-blacklist')) {
    ref.invalidate(onlineGalleryBlacklistNotifierProvider);
  }
  if (adapterIds.contains('online-gallery-favorites')) {
    ref.invalidate(onlineGalleryLocalFavoritesProvider);
  }
  if (adapterIds.contains('gallery-albums')) {
    await ref.read(galleryAlbumNotifierProvider.notifier).refresh();
  }
  if (adapterIds.contains('vibe-library')) {
    await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    ref.invalidate(vibeLibraryCategoryNotifierProvider);
  }
  if (adapterIds.contains('precise-ref-library')) {
    await ref.read(preciseRefLibraryNotifierProvider.notifier).reload();
  }
}
