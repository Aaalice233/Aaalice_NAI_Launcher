/// 存储键名常量
class StorageKeys {
  StorageKeys._();

  // Secure Storage Keys (敏感数据)
  static const String accessToken = 'nai_access_token';
  static const String tokenExpiry = 'nai_token_expiry';
  static const String userEmail = 'nai_user_email';

  // Token 存储（按账号ID）
  static const String accountTokenPrefix = 'nai_account_token_';

  // Hive Box Names
  static const String settingsBox = 'settings';
  static const String historyBox = 'history';
  static const String cacheBox = 'cache';
  static const String tagCacheBox = 'tag_cache';
  static const String galleryBox = 'gallery';
  static const String localMetadataCacheBox = 'local_metadata_cache';
  static const String warmupMetricsBox = 'warmup_metrics';
  static const String tagFavoritesBox = 'tag_favorites';
  static const String tagTemplatesBox = 'tag_templates';
  static const String localFavoritesBox = 'local_favorites';
  static const String searchIndexBox = 'search_index';
  static const String favoritesBox = 'favorites';
  static const String tagsBox = 'tags';

  // Settings Keys
  static const String themeType = 'theme_type';
  static const String fontFamily = 'font_family';
  static const String locale = 'locale';

  // Window State Keys (窗口状态)
  static const String windowWidth = 'window_width';
  static const String windowHeight = 'window_height';
  static const String windowX = 'window_x';
  static const String windowY = 'window_y';

  // UI Layout State Keys (UI布局状态)
  static const String leftPanelExpanded = 'left_panel_expanded';
  static const String rightPanelExpanded = 'right_panel_expanded';
  static const String leftPanelWidth = 'left_panel_width';
  static const String promptAreaHeight = 'prompt_area_height';
  static const String promptMaximized = 'prompt_maximized';

  // Panel Width Keys (面板宽度)
  static const String historyPanelWidth = 'history_panel_width';
  static const String defaultModel = 'default_model';
  static const String defaultSampler = 'default_sampler';
  static const String defaultSteps = 'default_steps';
  static const String defaultScale = 'default_scale';
  static const String defaultWidth = 'default_width';
  static const String defaultHeight = 'default_height';
  static const String selectedResolutionPresetId =
      'selected_resolution_preset_id';
  static const String imageSavePath = 'image_save_path';
  static const String autoSaveImages = 'auto_save_images';
  static const String addQualityTags = 'add_quality_tags';
  static const String ucPresetType = 'uc_preset_type';
  static const String randomPromptMode = 'random_prompt_mode';
  static const String imagesPerRequest = 'images_per_request';
  static const String enableAutocomplete = 'enable_autocomplete';
  static const String autoFormatPrompt = 'auto_format_prompt';
  static const String highlightEmphasis = 'highlight_emphasis';
  static const String sdSyntaxAutoConvert = 'sd_syntax_auto_convert';

  // Seed Lock Keys (种子锁定相关)
  static const String seedLocked = 'seed_locked';
  static const String lockedSeedValue = 'locked_seed_value';

  // Last Generation Params Keys (持久化上次使用的参数)
  static const String lastPrompt = 'last_prompt';
  static const String lastNegativePrompt = 'last_negative_prompt';
  static const String lastSmea = 'last_smea';
  static const String lastSmeaDyn = 'last_smea_dyn';
  static const String lastCfgRescale = 'last_cfg_rescale';
  static const String lastNoiseSchedule = 'last_noise_schedule';

  // Gallery Keys (画廊相关)
  static const String generationHistory = 'generation_history';
  static const String historyIndex = 'history_index';
  static const String favoriteImages = 'favorite_images';

  // Tag Cache Keys (标签缓存相关)
  static const String tagCacheData = 'tag_cache_data';

  // Tag Favorites Keys (标签收藏相关)
  static const String tagFavoritesData = 'tag_favorites_data';

  // Tag Templates Keys (标签模板相关)
  static const String tagTemplatesData = 'tag_templates_data';

  // Local Gallery Keys (本地画廊相关)
  static const String hasSeenLocalGalleryTip = 'has_seen_local_gallery_tip';

  // Replication Queue Keys (复刻队列相关)
  static const String replicationQueueBox = 'replication_queue';
  static const String replicationQueueData = 'replication_queue_data';

  // Queue Settings (队列设置)
  static const String queueRetryCount = 'queue_retry_count';
  static const String queueRetryInterval = 'queue_retry_interval';
}
