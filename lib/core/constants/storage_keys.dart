/// 存储键名常量
class StorageKeys {
  StorageKeys._();

  // Secure Storage Keys (敏感数据)
  static const String accessToken = 'nai_access_token';
  static const String tokenExpiry = 'nai_token_expiry';
  static const String userEmail = 'nai_user_email';

  // 记住密码功能 (保存登录凭据)
  static const String savedEmail = 'nai_saved_email';
  static const String savedPassword = 'nai_saved_password';
  static const String rememberPassword = 'nai_remember_password';

  // Hive Box Names
  static const String settingsBox = 'settings';
  static const String historyBox = 'history';
  static const String cacheBox = 'cache';
  static const String tagCacheBox = 'tag_cache';
  static const String galleryBox = 'gallery';

  // Settings Keys
  static const String themeType = 'theme_type';
  static const String fontFamily = 'font_family';
  static const String locale = 'locale';
  static const String defaultModel = 'default_model';
  static const String defaultSampler = 'default_sampler';
  static const String defaultSteps = 'default_steps';
  static const String defaultScale = 'default_scale';
  static const String defaultWidth = 'default_width';
  static const String defaultHeight = 'default_height';
  static const String selectedResolutionPresetId = 'selected_resolution_preset_id';
  static const String imageSavePath = 'image_save_path';
  static const String autoSaveImages = 'auto_save_images';
  static const String addQualityTags = 'add_quality_tags';
  static const String ucPresetType = 'uc_preset_type';
  static const String randomPromptMode = 'random_prompt_mode';
  static const String imagesPerRequest = 'images_per_request';
  static const String enableAutocomplete = 'enable_autocomplete';
  static const String autoFormatPrompt = 'auto_format_prompt';
  static const String highlightEmphasis = 'highlight_emphasis';

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
}
