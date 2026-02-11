/// 默认快捷键定义
/// 包含所有快捷键的ID常量和默认配置
class ShortcutIds {
  // 页面导航快捷键
  static const String navigateToGeneration = 'navigate_to_generation';
  static const String navigateToLocalGallery = 'navigate_to_local_gallery';
  static const String navigateToOnlineGallery = 'navigate_to_online_gallery';
  static const String navigateToRandomConfig = 'navigate_to_random_config';
  static const String navigateToTagLibrary = 'navigate_to_tag_library';
  static const String navigateToStatistics = 'navigate_to_statistics';
  static const String navigateToSettings = 'navigate_to_settings';
  static const String navigateToVibeLibrary = 'navigate_to_vibe_library';

  // 生成页面快捷键
  static const String generateImage = 'generate_image';
  static const String cancelGeneration = 'cancel_generation';
  static const String addToQueue = 'add_to_queue';
  static const String randomPrompt = 'random_prompt';
  static const String clearPrompt = 'clear_prompt';
  static const String togglePromptMode = 'toggle_prompt_mode';
  static const String openTagLibrary = 'open_tag_library';
  static const String saveImage = 'save_image';
  static const String upscaleImage = 'upscale_image';
  static const String copyImage = 'copy_image';
  static const String fullscreenPreview = 'fullscreen_preview';
  static const String openParamsPanel = 'open_params_panel';
  static const String openHistoryPanel = 'open_history_panel';
  static const String reuseParams = 'reuse_params';

  // 画廊快捷键（查看器）
  static const String previousImage = 'previous_image';
  static const String nextImage = 'next_image';
  static const String zoomIn = 'zoom_in';
  static const String zoomOut = 'zoom_out';
  static const String resetZoom = 'reset_zoom';
  static const String toggleFullscreen = 'toggle_fullscreen';
  static const String closeViewer = 'close_viewer';
  static const String toggleFavorite = 'toggle_favorite';
  static const String copyPrompt = 'copy_prompt';
  static const String reuseGalleryParams = 'reuse_gallery_params';
  static const String deleteImage = 'delete_image';

  // 画廊快捷键（列表）
  static const String previousPage = 'previous_page';
  static const String nextPage = 'next_page';
  static const String refreshGallery = 'refresh_gallery';
  static const String focusSearch = 'focus_search';
  static const String enterSelectionMode = 'enter_selection_mode';
  static const String openFilterPanel = 'open_filter_panel';
  static const String clearFilter = 'clear_filter';
  static const String toggleCategoryPanel = 'toggle_category_panel';
  static const String jumpToDate = 'jump_to_date';
  static const String openFolder = 'open_folder';

  // 词库页面快捷键
  static const String selectAllTags = 'select_all_tags';
  static const String deselectAllTags = 'deselect_all_tags';
  static const String newCategory = 'new_category';
  static const String newTag = 'new_tag';
  static const String searchTags = 'search_tags';
  static const String batchDeleteTags = 'batch_delete_tags';
  static const String batchCopyTags = 'batch_copy_tags';
  static const String sendToHome = 'send_to_home';
  static const String exitSelectionMode = 'exit_selection_mode';

  // 随机配置页面快捷键
  static const String syncDanbooru = 'sync_danbooru';
  static const String generatePreview = 'generate_preview';
  static const String searchPresets = 'search_presets';
  static const String newPreset = 'new_preset';
  static const String duplicatePreset = 'duplicate_preset';
  static const String deletePreset = 'delete_preset';
  static const String closeConfig = 'close_config';

  // 全局应用快捷键
  static const String minimizeToTray = 'minimize_to_tray';
  static const String quitApp = 'quit_app';
  static const String showShortcutHelp = 'show_shortcut_help';
  static const String toggleQueue = 'toggle_queue';
  static const String toggleQueuePause = 'toggle_queue_pause';
  static const String toggleTheme = 'toggle_theme';
}

/// 快捷键上下文枚举
enum ShortcutContext {
  global, // 全局
  generation, // 生成页
  gallery, // 画廊列表
  viewer, // 图片查看器
  tagLibrary, // 词库
  randomConfig, // 随机配置
  settings, // 设置
  input, // 输入框（编辑状态）
}

/// 快捷键上下文扩展
extension ShortcutContextExtension on ShortcutContext {
  String get displayName {
    switch (this) {
      case ShortcutContext.global:
        return '全局';
      case ShortcutContext.generation:
        return '生成页面';
      case ShortcutContext.gallery:
        return '画廊列表';
      case ShortcutContext.viewer:
        return '图片查看器';
      case ShortcutContext.tagLibrary:
        return '词库';
      case ShortcutContext.randomConfig:
        return '随机配置';
      case ShortcutContext.settings:
        return '设置';
      case ShortcutContext.input:
        return '输入框';
    }
  }

  String get i18nKey {
    switch (this) {
      case ShortcutContext.global:
        return 'shortcut_context_global';
      case ShortcutContext.generation:
        return 'shortcut_context_generation';
      case ShortcutContext.gallery:
        return 'shortcut_context_gallery';
      case ShortcutContext.viewer:
        return 'shortcut_context_viewer';
      case ShortcutContext.tagLibrary:
        return 'shortcut_context_tag_library';
      case ShortcutContext.randomConfig:
        return 'shortcut_context_random_config';
      case ShortcutContext.settings:
        return 'shortcut_context_settings';
      case ShortcutContext.input:
        return 'shortcut_context_input';
    }
  }
}

/// 默认快捷键配置
class DefaultShortcuts {
  /// 获取所有默认快捷键配置
  /// 格式: Map<快捷键ID, 默认快捷键字符串>
  static Map<String, String> get all => {
        // 页面导航
        ShortcutIds.navigateToGeneration: 'ctrl+1',
        ShortcutIds.navigateToLocalGallery: 'ctrl+2',
        ShortcutIds.navigateToOnlineGallery: 'ctrl+3',
        ShortcutIds.navigateToRandomConfig: 'ctrl+4',
        ShortcutIds.navigateToTagLibrary: 'ctrl+5',
        ShortcutIds.navigateToStatistics: 'ctrl+6',
        ShortcutIds.navigateToSettings: 'ctrl+comma',
        ShortcutIds.navigateToVibeLibrary: 'ctrl+7',

        // 生成页面
        ShortcutIds.generateImage: 'ctrl+enter',
        ShortcutIds.cancelGeneration: 'escape',
        ShortcutIds.addToQueue: 'ctrl+shift+enter',
        ShortcutIds.randomPrompt: 'ctrl+r',
        ShortcutIds.clearPrompt: 'ctrl+l',
        ShortcutIds.togglePromptMode: 'ctrl+m',
        ShortcutIds.openTagLibrary: 'ctrl+t',
        ShortcutIds.saveImage: 'ctrl+s',
        ShortcutIds.upscaleImage: 'ctrl+u',
        ShortcutIds.copyImage: 'ctrl+shift+c',
        ShortcutIds.fullscreenPreview: 'space',
        ShortcutIds.openParamsPanel: 'ctrl+p',
        ShortcutIds.openHistoryPanel: 'ctrl+h',
        ShortcutIds.reuseParams: 'ctrl+e',

        // 画廊查看器
        ShortcutIds.previousImage: 'arrowleft',
        ShortcutIds.nextImage: 'arrowright',
        ShortcutIds.zoomIn: 'equal',
        ShortcutIds.zoomOut: 'minus',
        ShortcutIds.resetZoom: 'digit0',
        ShortcutIds.toggleFullscreen: 'f11',
        ShortcutIds.closeViewer: 'escape',
        ShortcutIds.toggleFavorite: 'f',
        ShortcutIds.copyPrompt: 'ctrl+c',
        ShortcutIds.reuseGalleryParams: 'ctrl+r',
        ShortcutIds.deleteImage: 'delete',

        // 画廊列表
        ShortcutIds.previousPage: 'pageup',
        ShortcutIds.nextPage: 'pagedown',
        ShortcutIds.refreshGallery: 'f5',
        ShortcutIds.focusSearch: 'ctrl+f',
        ShortcutIds.enterSelectionMode: 'ctrl+a',
        ShortcutIds.openFilterPanel: 'ctrl+shift+f',
        ShortcutIds.clearFilter: 'ctrl+shift+c',
        ShortcutIds.toggleCategoryPanel: 'ctrl+b',
        ShortcutIds.jumpToDate: 'ctrl+g',
        ShortcutIds.openFolder: 'ctrl+o',

        // 词库
        ShortcutIds.selectAllTags: 'ctrl+a',
        ShortcutIds.deselectAllTags: 'ctrl+shift+a',
        ShortcutIds.newCategory: 'ctrl+shift+n',
        ShortcutIds.newTag: 'ctrl+n',
        ShortcutIds.searchTags: 'ctrl+f',
        ShortcutIds.batchDeleteTags: 'delete',
        ShortcutIds.batchCopyTags: 'ctrl+c',
        ShortcutIds.sendToHome: 'enter',
        ShortcutIds.exitSelectionMode: 'escape',

        // 随机配置
        ShortcutIds.syncDanbooru: 'ctrl+s',
        ShortcutIds.generatePreview: 'ctrl+g',
        ShortcutIds.searchPresets: 'ctrl+f',
        ShortcutIds.newPreset: 'ctrl+n',
        ShortcutIds.duplicatePreset: 'ctrl+d',
        ShortcutIds.deletePreset: 'delete',
        ShortcutIds.closeConfig: 'escape',

        // 全局
        ShortcutIds.minimizeToTray: 'ctrl+m',
        ShortcutIds.quitApp: 'ctrl+q',
        ShortcutIds.showShortcutHelp: 'f1',
        ShortcutIds.toggleQueue: 'ctrl+j',
        ShortcutIds.toggleQueuePause: 'ctrl+space',
        ShortcutIds.toggleTheme: 'ctrl+shift+t',
      };

  /// 获取快捷键的上下文
  static ShortcutContext getContext(String shortcutId) {
    switch (shortcutId) {
      // 页面导航
      case ShortcutIds.navigateToGeneration:
      case ShortcutIds.navigateToLocalGallery:
      case ShortcutIds.navigateToOnlineGallery:
      case ShortcutIds.navigateToRandomConfig:
      case ShortcutIds.navigateToTagLibrary:
      case ShortcutIds.navigateToStatistics:
      case ShortcutIds.navigateToSettings:
      case ShortcutIds.navigateToVibeLibrary:
      case ShortcutIds.minimizeToTray:
      case ShortcutIds.quitApp:
      case ShortcutIds.showShortcutHelp:
      case ShortcutIds.toggleQueue:
      case ShortcutIds.toggleQueuePause:
      case ShortcutIds.toggleTheme:
        return ShortcutContext.global;

      // 生成页面
      case ShortcutIds.generateImage:
      case ShortcutIds.cancelGeneration:
      case ShortcutIds.addToQueue:
      case ShortcutIds.randomPrompt:
      case ShortcutIds.clearPrompt:
      case ShortcutIds.togglePromptMode:
      case ShortcutIds.openTagLibrary:
      case ShortcutIds.saveImage:
      case ShortcutIds.upscaleImage:
      case ShortcutIds.copyImage:
      case ShortcutIds.fullscreenPreview:
      case ShortcutIds.openParamsPanel:
      case ShortcutIds.openHistoryPanel:
      case ShortcutIds.reuseParams:
        return ShortcutContext.generation;

      // 画廊查看器
      case ShortcutIds.previousImage:
      case ShortcutIds.nextImage:
      case ShortcutIds.zoomIn:
      case ShortcutIds.zoomOut:
      case ShortcutIds.resetZoom:
      case ShortcutIds.toggleFullscreen:
      case ShortcutIds.closeViewer:
      case ShortcutIds.toggleFavorite:
      case ShortcutIds.copyPrompt:
      case ShortcutIds.reuseGalleryParams:
      case ShortcutIds.deleteImage:
        return ShortcutContext.viewer;

      // 画廊列表
      case ShortcutIds.previousPage:
      case ShortcutIds.nextPage:
      case ShortcutIds.refreshGallery:
      case ShortcutIds.focusSearch:
      case ShortcutIds.enterSelectionMode:
      case ShortcutIds.openFilterPanel:
      case ShortcutIds.clearFilter:
      case ShortcutIds.toggleCategoryPanel:
      case ShortcutIds.jumpToDate:
      case ShortcutIds.openFolder:
        return ShortcutContext.gallery;

      // 词库
      case ShortcutIds.selectAllTags:
      case ShortcutIds.deselectAllTags:
      case ShortcutIds.newCategory:
      case ShortcutIds.newTag:
      case ShortcutIds.searchTags:
      case ShortcutIds.batchDeleteTags:
      case ShortcutIds.batchCopyTags:
      case ShortcutIds.sendToHome:
      case ShortcutIds.exitSelectionMode:
        return ShortcutContext.tagLibrary;

      // 随机配置
      case ShortcutIds.syncDanbooru:
      case ShortcutIds.generatePreview:
      case ShortcutIds.searchPresets:
      case ShortcutIds.newPreset:
      case ShortcutIds.duplicatePreset:
      case ShortcutIds.deletePreset:
      case ShortcutIds.closeConfig:
        return ShortcutContext.randomConfig;

      default:
        return ShortcutContext.global;
    }
  }

  /// 获取快捷键的i18n键
  static String getI18nKey(String shortcutId) {
    return 'shortcut_action_$shortcutId';
  }

  /// 获取快捷键的默认启用状态
  static bool isEnabledByDefault(String shortcutId) {
    // 所有快捷键默认启用
    return true;
  }
}
