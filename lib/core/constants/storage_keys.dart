/// 存储键名常量
class StorageKeys {
  StorageKeys._();

  // Secure Storage Keys (敏感数据)
  static const String accessToken = 'nai_access_token';
  static const String tokenExpiry = 'nai_token_expiry';
  static const String userEmail = 'nai_user_email';

  // Token 存储（按账号ID）
  static const String accountTokenPrefix = 'nai_account_token_';

  // Access Key 存储（用于 JWT token 刷新，按账号ID）
  static const String accountAccessKeyPrefix = 'nai_account_access_key_';

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
  static const String collectionsBox = 'collections';

  // Settings Keys
  static const String themeType = 'theme_type';
  static const String fontFamily = 'font_family';
  static const String fontScale = 'font_scale';
  static const String locale = 'locale';
  static const String fileLoggingEnabled = 'file_logging_enabled';

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
  static const String generationLayoutMode = 'generation_layout_mode';
  static const String webLeftPanelWidth = 'web_left_panel_width';
  static const String webLeftPanelExpanded = 'web_left_panel_expanded';
  static const String fixedTagsSidebarExpanded = 'fixed_tags_sidebar_expanded';
  static const String fixedTagsSidebarWidth = 'fixed_tags_sidebar_width';
  static const String fixedTagsSidebarViewMode = 'fixed_tags_sidebar_view_mode';
  static const String fixedTagsNegativeHeight = 'fixed_tags_negative_height';

  // Panel Expansion State Keys (面板展开状态)
  static const String advancedOptionsExpanded = 'advanced_options_expanded';
  static const String img2imgExpanded = 'img2img_expanded';
  static const String vibeTransferExpanded = 'vibe_transfer_expanded';
  static const String preciseRefExpanded = 'precise_ref_expanded';
  static const String characterPanelExpanded = 'character_panel_expanded';

  // Character Panel Dock State (多角色面板停靠状态)
  static const String characterPanelDocked = 'character_panel_docked';

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
  static const String shareStripMetadata = 'share_strip_metadata';
  static const String addQualityTags = 'add_quality_tags';
  static const String ucPresetType = 'uc_preset_type';

  // 质量词预设（新版）
  static const String qualityPresetMode = 'quality_preset_mode';
  static const String qualityPresetCustomId = 'quality_preset_custom_id';
  static const String qualityPresetCustomIds =
      'quality_preset_custom_ids'; // 自定义条目ID列表

  // 负面词自定义条目
  static const String ucPresetCustomId = 'uc_preset_custom_id';
  static const String ucPresetCustomIds = 'uc_preset_custom_ids'; // 自定义条目ID列表
  static const String randomPromptMode = 'random_prompt_mode';
  static const String showRandomPromptTools = 'show_random_prompt_tools';
  static const String randomGenerationMode = 'random_generation_mode';
  static const String imagesPerRequest = 'images_per_request';
  static const String enableAutocomplete = 'enable_autocomplete';
  static const String autoFormatPrompt = 'auto_format_prompt';
  static const String highlightEmphasis = 'highlight_emphasis';
  static const String sdSyntaxAutoConvert = 'sd_syntax_auto_convert';
  static const String enablePromptWeightScroll = 'enable_prompt_weight_scroll';

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
  static const String lastVarietyPlus = 'last_variety_plus';

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

  // Vibe Library Keys (Vibe库相关)
  static const String vibeLibrarySavePath = 'vibe_library_save_path';
  static const String vibeRecentCollapsed = 'vibe_recent_collapsed';

  // Replication Queue Keys (复刻队列相关)
  static const String replicationQueueBox = 'replication_queue';
  static const String replicationQueueData = 'replication_queue_data';

  // Queue Settings (队列设置)
  static const String queueRetryCount = 'queue_retry_count';
  static const String queueRetryInterval = 'queue_retry_interval';
  static const String queueAutoExecute = 'queue_auto_execute';
  static const String queueTaskInterval = 'queue_task_interval';
  static const String queueFailureStrategy = 'queue_failure_strategy';

  // Queue Execution State (队列执行状态)
  static const String queueExecutionStateBox = 'queue_execution_state';
  static const String queueExecutionStateData = 'queue_execution_state_data';
  static const String queueFailedTasksData = 'queue_failed_tasks_data';
  static const String queueExecutionHistory = 'queue_execution_history';

  // Floating Button Position (悬浮球位置)
  static const String floatingButtonX = 'floating_button_x';
  static const String floatingButtonY = 'floating_button_y';
  static const String floatingButtonFirstLaunch =
      'floating_button_first_launch';
  static const String floatingButtonExpanded = 'floating_button_expanded';
  static const String floatingButtonBackgroundImage =
      'floating_button_background_image';

  // Proxy Settings (代理设置)
  static const String proxyEnabled = 'proxy_enabled';
  static const String proxyMode = 'proxy_mode';
  static const String proxyManualHost = 'proxy_manual_host';
  static const String proxyManualPort = 'proxy_manual_port';

  // Fixed Tags (固定词相关)
  static const String fixedTagsBox = 'fixed_tags';
  static const String fixedTagsData = 'fixed_tags_data';
  static const String fixedTagLinksData = 'fixed_tag_links_data';
  static const String fixedTagsNegativePanelExpanded =
      'fixed_tags_negative_panel_expanded';
  static const String fixedTagCategoriesData = 'fixed_tag_categories_data';

  // Tag Library (词库相关)
  static const String tagLibraryUserBox = 'tag_library_user';
  static const String tagLibraryEntriesData = 'tag_library_entries_data';
  static const String tagLibraryCategoriesData = 'tag_library_categories_data';
  static const String tagLibraryViewMode = 'tag_library_view_mode';
  static const String tagLibraryPickerCategoryId =
      'tag_library_picker_category_id';

  // Statistics Cache (统计数据缓存)
  static const String statisticsCacheBox = 'statistics_cache';
  static const String statisticsCacheData = 'statistics_cache_data';
  static const String statisticsCacheMetadata = 'statistics_cache_metadata';

  // Notification Settings (音效设置)
  static const String notificationSoundEnabled = 'notification_sound_enabled';
  static const String notificationCustomSoundPath =
      'notification_custom_sound_path';

  // Update Check Keys (更新检查相关)
  static const String lastUpdateCheckTime = 'last_update_check_time';
  static const String skippedUpdateVersion = 'skipped_update_version';
  static const String includePrereleaseUpdates = 'include_prerelease_updates';

  // Data Source Cache Settings (数据源缓存设置)
  static const String hfTranslationRefreshInterval =
      'hf_translation_refresh_interval';
  static const String hfTranslationLastUpdate = 'hf_translation_last_update';
  static const String danbooruTagsHotThreshold = 'danbooru_tags_hot_threshold';
  static const String danbooruTagsHotPreset = 'danbooru_tags_hot_preset';
  static const String danbooruTagsLastUpdate = 'danbooru_tags_last_update';
  static const String danbooruTagsRefreshInterval =
      'danbooru_tags_refresh_interval';
  static const String danbooruTagsRefreshIntervalDays =
      'danbooru_tags_refresh_interval_days';
  static const String firstLaunchVersion = 'first_launch_version';
  static const String enableSmartTagRecommendation =
      'enable_smart_tag_recommendation';
  static const String enableCooccurrenceRecommendation =
      'enable_cooccurrence_recommendation';

  // Prompt Assistant
  static const String promptAssistantConfigJson =
      'prompt_assistant_config_json';
  static const String promptAssistantApiKeyPrefix = 'prompt_assistant_api_key_';

  // Danbooru 画师同步设置
  // 分类阈值配置（V2新增）
  static const String danbooruCategoryThresholds =
      'danbooru_category_thresholds';

  // 五个类别的独立热度阈值
  static const String danbooruGeneralThreshold = 'danbooru_general_threshold';
  static const String danbooruArtistThreshold = 'danbooru_artist_threshold';
  static const String danbooruCharacterThreshold =
      'danbooru_character_threshold';
  static const String danbooruCopyrightThreshold =
      'danbooru_copyright_threshold';
  static const String danbooruMetaThreshold = 'danbooru_meta_threshold';

  // 共现数据刷新间隔
  static const String cooccurrenceRefreshInterval =
      'cooccurrence_refresh_interval';

  // 数据源后台刷新相关
  static const String pendingDataSourceRefresh = 'pending_data_source_refresh';

  // 在线画廊黑名单设置
  static const String onlineGalleryBlacklistTags =
      'online_gallery_blacklist_tags';
  static const String onlineGalleryRemoteBlacklistTags =
      'online_gallery_remote_blacklist_tags';
  static const String onlineGalleryBlacklistAutoSync =
      'online_gallery_blacklist_auto_sync';
  static const String onlineGalleryBlacklistLastSyncAt =
      'online_gallery_blacklist_last_sync_at';
  static const String onlineGalleryBlacklistLastSyncError =
      'online_gallery_blacklist_last_sync_error';

  // ComfyUI 设置
  static const String comfyuiEnabled = 'comfyui_enabled';
  static const String comfyuiServerUrl = 'comfyui_server_url';
  static const String comfyuiUpscaleModel = 'comfyui_upscale_model';
  static const String comfyuiUpscaleRegularModel =
      'comfyui_upscale_regular_model';
  static const String comfyuiUpscaleSeedvr2Model =
      'comfyui_upscale_seedvr2_model';
  static const String comfyuiUpscaleScale = 'comfyui_upscale_scale';
  static const String comfyuiUpscaleBackend = 'comfyui_upscale_backend';
  static const String comfyuiUpscaleModule = 'comfyui_upscale_module';
  static const String comfyuiSeedvr2VaeTileSize =
      'comfyui_seedvr2_vae_tile_size';
  static const String comfyuiSeedvr2Tiled = 'comfyui_seedvr2_tiled';
  static const String comfyuiSeedvr2TileSize = 'comfyui_seedvr2_tile_size';

  // Krita Bridge 设置
  static const String kritaBridgeEnabled = 'krita_bridge_enabled';

  // 工作流设置
  static const String workflowEnhanceMagnitude = 'workflow_enhance_magnitude';
  static const String workflowEnhanceShowIndividualSettings =
      'workflow_enhance_show_individual_settings';
  static const String workflowEnhanceUpscaleFactor =
      'workflow_enhance_upscale_factor';
  static const String workflowEnhanceStrength = 'workflow_enhance_strength';
  static const String workflowEnhanceNoise = 'workflow_enhance_noise';

  // 反推/本地模型设置
  static const String reversePromptStateJson = 'reverse_prompt_state_json';
  static const String reversePromptCharacterConfigJson =
      'reverse_prompt_character_config_json';
  static const String onnxTaggerModelDirectory = 'onnx_tagger_model_directory';

  // 保护模式设置
  static const String protectionMode = 'protection_mode';
  static const String protectionConfirmDangerousActions =
      'protection_confirm_dangerous_actions';
  static const String protectionWarnExternalImageSend =
      'protection_warn_external_image_send';
  static const String protectionPreventOverwrite =
      'protection_prevent_overwrite';
  static const String protectionWarnHighAnlasCost =
      'protection_warn_high_anlas_cost';
  static const String protectionHighAnlasCostThreshold =
      'protection_high_anlas_cost_threshold';

  // 旧版资产保护 key，保留读取兼容。
  static const String assetProtectionMode = 'asset_protection_mode';
}
