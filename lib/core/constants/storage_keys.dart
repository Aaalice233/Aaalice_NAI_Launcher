/// 存储键名常量
class StorageKeys {
  StorageKeys._();

  // Secure Storage Keys (敏感数据)
  static const String accessToken = 'nai_access_token';
  static const String tokenExpiry = 'nai_token_expiry';
  static const String userEmail = 'nai_user_email';
  static const String discordShareSession = 'discord_share_session_v1';
  static const String cloudSyncCredentials = 'cloud_sync_credentials_v1';
  static const String cloudSyncPendingFfdkjInstall =
      'cloud_sync_pending_ffdkj_install_v1';
  static const String cloudSyncConfiguration = 'cloud_sync_configuration_v1';
  static const String cloudDriveConfiguration = 'cloud_drive_configuration_v1';
  static const String cloudSyncDeviceId = 'cloud_sync_device_id_v1';
  static const String cloudSyncContentSelection =
      'cloud_sync_content_selection_v1';
  static const String cloudDriveOAuthSessionPrefix =
      'cloud_drive_oauth_session_v1_';

  // Token 存储（按账号ID）
  static const String accountTokenPrefix = 'nai_account_token_';

  // Access Key 存储（用于 JWT token 刷新，按账号ID）
  static const String accountAccessKeyPrefix = 'nai_account_access_key_';

  // Hive Box Names
  static const String settingsBox = 'settings';
  static const String historyBox = 'history';
  static const String cacheBox = 'cache';
  static const String galleryBox = 'gallery';
  static const String localMetadataCacheBox = 'local_metadata_cache';
  static const String warmupMetricsBox = 'warmup_metrics';
  static const String tagFavoritesBox = 'tag_favorites';
  static const String tagTemplatesBox = 'tag_templates';
  static const String localFavoritesBox = 'local_favorites';
  static const String favoritesBox = 'favorites';
  static const String tagsBox = 'tags';
  static const String collectionsBox = 'collections';

  // Settings Keys
  static const String themeType = 'theme_type';
  static const String fontFamily = 'font_family';
  static const String fontScale = 'font_scale';
  static const String locale = 'locale';
  static const String fileLoggingEnabled = 'file_logging_enabled';
  static const String watermarkConfigV1 = 'watermark_config_v1';
  static const String watermarkLogoPathV1 = 'watermark_logo_path_v1';
  static const String watermarkDerivativeRegistryV1 =
      'watermark_derivative_registry_v1';

  // Gallery album migration flag (图库相簿一次性导入标记)
  static const String galleryAlbumImportDone = 'gallery_album_import_done_v1';

  // Window State Keys (窗口状态)
  static const String windowWidth = 'window_width';
  static const String windowHeight = 'window_height';
  static const String windowX = 'window_x';
  static const String windowY = 'window_y';
  static const String windowStateV2 = 'window_state_v2';

  // UI Layout State Keys (UI布局状态)
  static const String leftPanelExpanded = 'left_panel_expanded';
  static const String rightPanelExpanded = 'right_panel_expanded';
  static const String leftPanelWidth = 'left_panel_width';
  static const String promptAreaHeight = 'prompt_area_height';
  static const String promptMaximized = 'prompt_maximized';
  static const String generationLayoutMode = 'generation_layout_mode';
  static const String mobileGenerationGestureHintCompleted =
      'mobile_generation_gesture_hint_completed';
  static const String historyClickBehavior = 'history_click_behavior';
  static const String previewTransparencyBackground =
      'preview_transparency_background';
  static const String compositionGuideMode = 'composition_guide_mode';
  static const String compositionGuideColumns = 'composition_guide_columns';
  static const String compositionGuideRows = 'composition_guide_rows';
  static const String mainNavRailExpanded = 'main_nav_rail_expanded';
  static const String webLeftPanelWidth = 'web_left_panel_width';
  static const String webLeftPanelExpanded = 'web_left_panel_expanded';
  static const String fixedTagsSidebarExpanded = 'fixed_tags_sidebar_expanded';
  static const String fixedTagsSidebarWidth = 'fixed_tags_sidebar_width';
  static const String fixedTagsSidebarViewMode = 'fixed_tags_sidebar_view_mode';
  static const String fixedTagsNegativeHeight = 'fixed_tags_negative_height';

  // Generation Workbench Panel Expansion State Keys (生图工作台面板展开状态)
  static const String advancedOptionsExpanded = 'advanced_options_expanded';
  static const String generationParamsMenuExpanded =
      'generation_params_menu_expanded';
  static const String characterPanelExpanded = 'character_panel_expanded';
  static const String reversePromptExpanded = 'reverse_prompt_expanded';
  static const String img2imgExpanded = 'img2img_expanded';
  static const String vibeTransferExpanded = 'vibe_transfer_expanded';
  static const String preciseRefExpanded = 'precise_ref_expanded';

  // Panel Width Keys (面板宽度)
  static const String historyPanelWidth = 'history_panel_width';
  static const String rightPanelTab = 'right_panel_tab';
  static const String agentChatActiveSession = 'agent_chat_active_session';
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
  static const String imageStraightAlpha = 'image_straight_alpha';
  static const String shareStripMetadata = 'share_strip_metadata';
  static const String addQualityTags = 'add_quality_tags';
  static const String ucPresetType = 'uc_preset_type';

  // 质量词预设（新版）
  static const String qualityPresetMode = 'quality_preset_mode';
  static const String qualityPresetNaiTier = 'quality_preset_nai_tier';
  static const String qualityPresetCustomId = 'quality_preset_custom_id';
  static const String qualityPresetCustomIds =
      'quality_preset_custom_ids'; // 自定义条目ID列表

  // 负面词自定义条目
  static const String ucPresetCustomId = 'uc_preset_custom_id';
  static const String ucPresetCustomIds = 'uc_preset_custom_ids'; // 自定义条目ID列表
  static const String randomPromptMode = 'random_prompt_mode';
  static const String showRandomPromptTools = 'show_random_prompt_tools';
  static const String generationStreamPreviewEnabled =
      'generation_stream_preview_enabled';
  static const String imagesPerRequest = 'images_per_request';
  static const String enableAutocomplete = 'enable_autocomplete';
  static const String autocompleteResultLimit = 'autocomplete_result_limit';
  static const String autocompleteShowAliases = 'autocomplete_show_aliases';
  static const String autocompleteShowTranslations =
      'autocomplete_show_translations';
  static const String autocompleteAutoComma = 'autocomplete_auto_comma';
  static const String autocompleteReplaceUnderscores =
      'autocomplete_replace_underscores';
  static const String autocompleteOpenOnTagClick =
      'autocomplete_open_on_tag_click';
  static const String autocompleteDanbooruEnabled =
      'autocomplete_danbooru_enabled';
  static const String autocompleteLlmTranslationEnabled =
      'autocomplete_llm_translation_enabled';
  static const String autocompleteZhInstallPromptDismissed =
      'autocomplete_zh_install_prompt_dismissed';
  static const String autocompleteMigrationVersion =
      'autocomplete_migration_version';
  static const String autoFormatPrompt = 'auto_format_prompt';
  static const String highlightEmphasis = 'highlight_emphasis';
  static const String sdSyntaxAutoConvert = 'sd_syntax_auto_convert';
  static const String resolveAliasOnCopy = 'resolve_alias_on_copy';
  static const String enablePromptWeightScroll = 'enable_prompt_weight_scroll';
  static const String promptRegexRules = 'prompt_regex_rules'; // 规则JSON字符串列表

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
  static const String lastTransparentBackground = 'last_transparent_background';
  static const String lastE2eUpscale = 'last_e2e_upscale';

  // Gallery Keys (画廊相关)
  static const String generationHistory = 'generation_history';
  static const String historyIndex = 'history_index';
  static const String favoriteImages = 'favorite_images';

  // Tag Favorites Keys (标签收藏相关)
  static const String tagFavoritesData = 'tag_favorites_data';

  // Tag Templates Keys (标签模板相关)
  static const String tagTemplatesData = 'tag_templates_data';

  // Local Gallery Keys (本地画廊相关)
  static const String hasSeenLocalGalleryTip = 'has_seen_local_gallery_tip';

  // Discord Share Keys
  static const String discordShareTargetIds = 'discord_share_target_ids_v1';
  static const String discordShareIncludeMetadata =
      'discord_share_include_metadata_v1';
  static const String discordSharePromptCategories =
      'discord_share_prompt_categories_v1';
  static const String discordShareLongPromptAsFile =
      'discord_share_long_prompt_as_file_v1';

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
  static const String lastUpdateCheckAttemptTime =
      'last_update_check_attempt_time';
  static const String skippedUpdateVersion = 'skipped_update_version';
  static const String lastKnownUpdateVersion = 'last_known_update_version';
  static const String updateRemindAfter = 'update_remind_after';
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
  static const String autoDownloadCooccurrenceData =
      'auto_download_cooccurrence_data';

  // Prompt Assistant
  static const String promptAssistantConfigJson =
      'prompt_assistant_config_json';
  static const String promptAssistantApiKeyPrefix = 'prompt_assistant_api_key_';
  static const String agentWebAccessConfigJson = 'agent_web_access_config_json';
  static const String agentWebAccessExaApiKey = 'agent_web_access_exa_api_key';
  static const String agentSettingsJson = 'agent_settings_json_v2';

  // 在线画廊凭据（系统安全存储）
  static const String onlineGalleryDanbooruCredentialsV1 =
      'online_gallery_danbooru_credentials_v1';
  static const String onlineGalleryGelbooruCredentialsV1 =
      'online_gallery_gelbooru_credentials_v1';

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

  // 在线画廊黑名单设置
  static const String onlineGalleryBlacklistTags =
      'online_gallery_blacklist_tags';
  static const String onlineGalleryBlacklistV2 = 'online_gallery_blacklist_v2';
  static const String onlineGalleryBlacklistRollbackShadow =
      'online_gallery_blacklist_rollback_shadow_v2';
  static const String onlineGalleryRemoteBlacklistTags =
      'online_gallery_remote_blacklist_tags';
  static const String onlineGalleryBlacklistAutoSync =
      'online_gallery_blacklist_auto_sync';
  static const String onlineGalleryBlacklistSource =
      'online_gallery_blacklist_source';
  static const String onlineGalleryBlacklistLastSyncAt =
      'online_gallery_blacklist_last_sync_at';
  static const String onlineGalleryBlacklistLastSyncError =
      'online_gallery_blacklist_last_sync_error';
  static const String onlineGalleryPromptTagCategories =
      'online_gallery_prompt_tag_categories';
  static const String onlineGalleryOutputFilterTags =
      'online_gallery_output_filter_tags';
  static const String onlineGalleryBrowsingSessionV1 =
      'online_gallery_browsing_session_v1';
  static const String quickTagCloudFavoritesV1 = 'quick_tag_cloud_favorites_v1';
  static const String quickTagCloudRecentV1 = 'quick_tag_cloud_recent_v1';
  static const String quickTagCloudContentAccessV1 =
      'quick_tag_cloud_content_access_v1';
  static const String quickTagCloudBrowsingFiltersV1 =
      'quick_tag_cloud_browsing_filters_v1';

  // ComfyUI 设置
  static const String comfyuiEnabled = 'comfyui_enabled';
  static const String comfyuiServerUrl = 'comfyui_server_url';
  static const String comfyuiUpscaleModel = 'comfyui_upscale_model';
  static const String comfyuiUpscaleRegularModel =
      'comfyui_upscale_regular_model';
  static const String comfyuiUpscaleSeedvr2Model =
      'comfyui_upscale_seedvr2_model';
  static const String comfyuiUpscaleSeedvr2NativeModel =
      'comfyui_upscale_seedvr2_native_model';
  static const String comfyuiUpscaleSeedvr2LegacyModel =
      'comfyui_upscale_seedvr2_legacy_model';
  static const String comfyuiUpscaleScale = 'comfyui_upscale_scale';
  static const String comfyuiUpscaleBackend = 'comfyui_upscale_backend';
  static const String comfyuiUpscaleModule = 'comfyui_upscale_module';
  static const String comfyuiSeedvr2VaeTileSize =
      'comfyui_seedvr2_vae_tile_size';
  static const String comfyuiSeedvr2Tiled = 'comfyui_seedvr2_tiled';
  static const String comfyuiSeedvr2TileSize = 'comfyui_seedvr2_tile_size';
  static const String comfyuiSeedvr2BlocksToSwap =
      'comfyui_seedvr2_blocks_to_swap';
  static const String comfyuiSeedvr2Engine = 'comfyui_seedvr2_engine';
  static const String comfyuiSeedvr2EmbedNaiMetadata =
      'comfyui_seedvr2_embed_nai_metadata';

  // Krita Bridge 设置
  static const String kritaBridgeEnabled = 'krita_bridge_enabled';

  // 工作流设置
  /// 旧版连续幅度（0-1），只用于迁移到 [workflowEnhanceLevel]。
  static const String workflowEnhanceMagnitude = 'workflow_enhance_magnitude';
  static const String workflowEnhanceLevel = 'workflow_enhance_level';
  static const String workflowEnhanceMaxScale = 'workflow_enhance_max_scale';
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
  static const String protectionLimitGenerationInterval =
      'protection_limit_generation_interval';
  static const String protectionGenerationIntervalSeconds =
      'protection_generation_interval_seconds';
  static const String protectionLastGenerationStartedAt =
      'protection_last_generation_started_at';

  // 旧版资产保护 key，保留读取兼容。
  static const String assetProtectionMode = 'asset_protection_mode';
}
