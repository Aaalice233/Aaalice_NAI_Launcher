import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';

part 'local_storage_service.g.dart';

/// 本地存储服务 - 存储非敏感配置数据
class LocalStorageService {
  /// 获取已打开的 settings box (在 main.dart 中预先打开)
  Box get _settingsBox => Hive.box(StorageKeys.settingsBox);

  /// 获取已打开的 history box (在 main.dart 中预先打开)
  Box get _historyBox => Hive.box(StorageKeys.historyBox);

  /// 初始化存储 (boxes 已在 main.dart 中打开，此方法保留兼容性)
  Future<void> init() async {
    // Boxes 已在 main.dart 中预先打开
  }

  // ==================== Settings ====================

  /// 获取设置值
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  /// 保存设置值
  Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  /// 删除设置
  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // ==================== Theme ====================

  /// 获取风格类型索引
  int getThemeIndex() {
    return getSetting<int>(StorageKeys.themeType, defaultValue: 0) ?? 0;
  }

  /// 保存主题类型索引
  Future<void> setThemeIndex(int index) async {
    await setSetting(StorageKeys.themeType, index);
  }

  // ==================== Font ====================

  /// 获取字体名称
  String getFontFamily() {
    return getSetting<String>(StorageKeys.fontFamily, defaultValue: 'system') ??
        'system';
  }

  /// 保存字体名称
  Future<void> setFontFamily(String fontFamily) async {
    await setSetting(StorageKeys.fontFamily, fontFamily);
  }

  // ==================== Locale ====================

  /// 获取语言代码
  String getLocaleCode() {
    return getSetting<String>(StorageKeys.locale, defaultValue: 'zh') ?? 'zh';
  }

  /// 保存语言代码
  Future<void> setLocaleCode(String code) async {
    await setSetting(StorageKeys.locale, code);
  }

  // ==================== Default Generation Params ====================

  /// 获取默认模型
  String getDefaultModel() {
    return getSetting<String>(
          StorageKeys.defaultModel,
          defaultValue: 'nai-diffusion-3',
        ) ??
        'nai-diffusion-3';
  }

  /// 保存默认模型
  Future<void> setDefaultModel(String model) async {
    await setSetting(StorageKeys.defaultModel, model);
  }

  /// 获取默认采样器
  String getDefaultSampler() {
    return getSetting<String>(
          StorageKeys.defaultSampler,
          defaultValue: 'k_euler_ancestral',
        ) ??
        'k_euler_ancestral';
  }

  /// 保存默认采样器
  Future<void> setDefaultSampler(String sampler) async {
    await setSetting(StorageKeys.defaultSampler, sampler);
  }

  /// 获取默认步数
  int getDefaultSteps() {
    return getSetting<int>(StorageKeys.defaultSteps, defaultValue: 28) ?? 28;
  }

  /// 保存默认步数
  Future<void> setDefaultSteps(int steps) async {
    await setSetting(StorageKeys.defaultSteps, steps);
  }

  /// 获取默认 Scale
  double getDefaultScale() {
    return getSetting<double>(StorageKeys.defaultScale, defaultValue: 5.0) ??
        5.0;
  }

  /// 保存默认 Scale
  Future<void> setDefaultScale(double scale) async {
    await setSetting(StorageKeys.defaultScale, scale);
  }

  /// 获取默认宽度
  int getDefaultWidth() {
    return getSetting<int>(StorageKeys.defaultWidth, defaultValue: 832) ?? 832;
  }

  /// 保存默认宽度
  Future<void> setDefaultWidth(int width) async {
    await setSetting(StorageKeys.defaultWidth, width);
  }

  /// 获取默认高度
  int getDefaultHeight() {
    return getSetting<int>(StorageKeys.defaultHeight, defaultValue: 1216) ??
        1216;
  }

  /// 保存默认高度
  Future<void> setDefaultHeight(int height) async {
    await setSetting(StorageKeys.defaultHeight, height);
  }

  /// 获取选中的分辨率预设 ID
  String? getSelectedResolutionPresetId() {
    return getSetting<String>(StorageKeys.selectedResolutionPresetId);
  }

  /// 保存选中的分辨率预设 ID
  Future<void> setSelectedResolutionPresetId(String? presetId) async {
    if (presetId != null) {
      await setSetting(StorageKeys.selectedResolutionPresetId, presetId);
    } else {
      await deleteSetting(StorageKeys.selectedResolutionPresetId);
    }
  }

  // ==================== Image Save ====================

  /// 获取图片保存路径
  String? getImageSavePath() {
    return getSetting<String>(StorageKeys.imageSavePath);
  }

  /// 保存图片保存路径
  Future<void> setImageSavePath(String path) async {
    await setSetting(StorageKeys.imageSavePath, path);
  }

  /// 获取是否自动保存图片
  bool getAutoSaveImages() {
    return getSetting<bool>(StorageKeys.autoSaveImages, defaultValue: false) ??
        false;
  }

  /// 保存是否自动保存图片
  Future<void> setAutoSaveImages(bool value) async {
    await setSetting(StorageKeys.autoSaveImages, value);
  }

  // ==================== Quality Tags ====================

  /// 获取是否添加质量标签 (默认开启)
  bool getAddQualityTags() {
    return getSetting<bool>(StorageKeys.addQualityTags, defaultValue: true) ??
        true;
  }

  /// 保存是否添加质量标签
  Future<void> setAddQualityTags(bool value) async {
    await setSetting(StorageKeys.addQualityTags, value);
  }

  // ==================== UC Preset ====================

  /// 获取 UC 预设类型 (默认 0 = Heavy)
  int getUcPresetType() {
    return getSetting<int>(StorageKeys.ucPresetType, defaultValue: 0) ?? 0;
  }

  /// 保存 UC 预设类型
  Future<void> setUcPresetType(int value) async {
    await setSetting(StorageKeys.ucPresetType, value);
  }

  /// 获取 UC 预设自定义条目 ID
  String? getUcPresetCustomId() {
    return getSetting<String>(StorageKeys.ucPresetCustomId);
  }

  /// 保存 UC 预设自定义条目 ID
  Future<void> setUcPresetCustomId(String? value) async {
    if (value != null) {
      await setSetting(StorageKeys.ucPresetCustomId, value);
    } else {
      await deleteSetting(StorageKeys.ucPresetCustomId);
    }
  }

  /// 获取 UC 预设自定义条目 ID 列表
  List<String> getUcPresetCustomIds() {
    final data = getSetting<List<dynamic>>(StorageKeys.ucPresetCustomIds);
    return data?.cast<String>() ?? [];
  }

  /// 保存 UC 预设自定义条目 ID 列表
  Future<void> setUcPresetCustomIds(List<String> ids) async {
    await setSetting(StorageKeys.ucPresetCustomIds, ids);
  }

  // ==================== Quality Preset (新版) ====================

  /// 获取质量词预设模式 (默认 0 = naiDefault)
  int getQualityPresetMode() {
    return getSetting<int>(StorageKeys.qualityPresetMode, defaultValue: 0) ?? 0;
  }

  /// 保存质量词预设模式
  Future<void> setQualityPresetMode(int value) async {
    await setSetting(StorageKeys.qualityPresetMode, value);
  }

  /// 获取质量词预设自定义条目 ID
  String? getQualityPresetCustomId() {
    return getSetting<String>(StorageKeys.qualityPresetCustomId);
  }

  /// 保存质量词预设自定义条目 ID
  Future<void> setQualityPresetCustomId(String? value) async {
    if (value != null) {
      await setSetting(StorageKeys.qualityPresetCustomId, value);
    } else {
      await deleteSetting(StorageKeys.qualityPresetCustomId);
    }
  }

  /// 获取质量词自定义条目 ID 列表
  List<String> getQualityPresetCustomIds() {
    final data = getSetting<List<dynamic>>(StorageKeys.qualityPresetCustomIds);
    return data?.cast<String>() ?? [];
  }

  /// 保存质量词自定义条目 ID 列表
  Future<void> setQualityPresetCustomIds(List<String> ids) async {
    await setSetting(StorageKeys.qualityPresetCustomIds, ids);
  }

  // ==================== Random Prompt Mode ====================

  /// 获取抽卡模式 (默认关闭)
  bool getRandomPromptMode() {
    return getSetting<bool>(
          StorageKeys.randomPromptMode,
          defaultValue: false,
        ) ??
        false;
  }

  /// 保存抽卡模式
  Future<void> setRandomPromptMode(bool value) async {
    await setSetting(StorageKeys.randomPromptMode, value);
  }

  /// 获取每次请求生成的图片数量 (默认1，最大4)
  int getImagesPerRequest() {
    return getSetting<int>(StorageKeys.imagesPerRequest, defaultValue: 1) ?? 1;
  }

  /// 保存每次请求生成的图片数量
  Future<void> setImagesPerRequest(int value) async {
    await setSetting(StorageKeys.imagesPerRequest, value.clamp(1, 4));
  }

  // ==================== Autocomplete ====================

  /// 获取是否启用自动补全 (默认开启)
  bool getEnableAutocomplete() {
    return getSetting<bool>(
          StorageKeys.enableAutocomplete,
          defaultValue: true,
        ) ??
        true;
  }

  /// 保存是否启用自动补全
  Future<void> setEnableAutocomplete(bool value) async {
    await setSetting(StorageKeys.enableAutocomplete, value);
  }

  // ==================== Auto Format ====================

  /// 获取是否启用自动格式化 (默认开启)
  bool getAutoFormatPrompt() {
    return getSetting<bool>(StorageKeys.autoFormatPrompt, defaultValue: true) ??
        true;
  }

  /// 保存是否启用自动格式化
  Future<void> setAutoFormatPrompt(bool value) async {
    await setSetting(StorageKeys.autoFormatPrompt, value);
  }

  /// 获取是否启用高亮强调 (默认开启)
  bool getHighlightEmphasis() {
    return getSetting<bool>(
          StorageKeys.highlightEmphasis,
          defaultValue: true,
        ) ??
        true;
  }

  /// 保存是否启用高亮强调
  Future<void> setHighlightEmphasis(bool value) async {
    await setSetting(StorageKeys.highlightEmphasis, value);
  }

  // ==================== SD Syntax Auto Convert ====================

  /// 获取是否启用SD语法自动转换 (默认关闭)
  bool getSdSyntaxAutoConvert() {
    return getSetting<bool>(
          StorageKeys.sdSyntaxAutoConvert,
          defaultValue: false,
        ) ??
        false;
  }

  /// 保存是否启用SD语法自动转换
  Future<void> setSdSyntaxAutoConvert(bool value) async {
    await setSetting(StorageKeys.sdSyntaxAutoConvert, value);
  }

  // ==================== Last Generation Params ====================

  /// 获取上次的正向提示词
  String getLastPrompt() {
    return getSetting<String>(StorageKeys.lastPrompt, defaultValue: '') ?? '';
  }

  /// 保存正向提示词
  Future<void> setLastPrompt(String prompt) async {
    await setSetting(StorageKeys.lastPrompt, prompt);
  }

  /// 获取上次的负向提示词
  String getLastNegativePrompt() {
    return getSetting<String>(
          StorageKeys.lastNegativePrompt,
          defaultValue: '',
        ) ??
        '';
  }

  /// 保存负向提示词
  Future<void> setLastNegativePrompt(String negativePrompt) async {
    await setSetting(StorageKeys.lastNegativePrompt, negativePrompt);
  }

  /// 获取上次的 SMEA 设置
  bool getLastSmea() {
    return getSetting<bool>(StorageKeys.lastSmea, defaultValue: true) ?? true;
  }

  /// 保存 SMEA 设置
  Future<void> setLastSmea(bool smea) async {
    await setSetting(StorageKeys.lastSmea, smea);
  }

  /// 获取上次的 SMEA DYN 设置
  bool getLastSmeaDyn() {
    return getSetting<bool>(StorageKeys.lastSmeaDyn, defaultValue: false) ??
        false;
  }

  /// 保存 SMEA DYN 设置
  Future<void> setLastSmeaDyn(bool smeaDyn) async {
    await setSetting(StorageKeys.lastSmeaDyn, smeaDyn);
  }

  /// 获取上次的 CFG Rescale 值
  double getLastCfgRescale() {
    return getSetting<double>(StorageKeys.lastCfgRescale, defaultValue: 0.0) ??
        0.0;
  }

  /// 保存 CFG Rescale 值
  Future<void> setLastCfgRescale(double cfgRescale) async {
    await setSetting(StorageKeys.lastCfgRescale, cfgRescale);
  }

  /// 获取上次的噪声计划
  String getLastNoiseSchedule() {
    return getSetting<String>(
          StorageKeys.lastNoiseSchedule,
          defaultValue: 'native',
        ) ??
        'native';
  }

  /// 保存噪声计划
  Future<void> setLastNoiseSchedule(String noiseSchedule) async {
    await setSetting(StorageKeys.lastNoiseSchedule, noiseSchedule);
  }

  // ==================== Seed Lock ====================

  /// 获取种子是否锁定 (默认关闭)
  bool getSeedLocked() {
    return getSetting<bool>(StorageKeys.seedLocked, defaultValue: false) ??
        false;
  }

  /// 保存种子锁定状态
  Future<void> setSeedLocked(bool locked) async {
    await setSetting(StorageKeys.seedLocked, locked);
  }

  /// 获取锁定的种子值 (默认为null)
  int? getLockedSeedValue() {
    return getSetting<int>(StorageKeys.lockedSeedValue);
  }

  /// 保存锁定的种子值
  Future<void> setLockedSeedValue(int? seed) async {
    if (seed != null) {
      await setSetting(StorageKeys.lockedSeedValue, seed);
    } else {
      await deleteSetting(StorageKeys.lockedSeedValue);
    }
  }

  // ==================== UI Layout State ====================

  /// 获取左侧面板展开状态 (默认展开)
  bool getLeftPanelExpanded() {
    return getSetting<bool>(
          StorageKeys.leftPanelExpanded,
          defaultValue: true,
        ) ??
        true;
  }

  /// 保存左侧面板展开状态
  Future<void> setLeftPanelExpanded(bool expanded) async {
    await setSetting(StorageKeys.leftPanelExpanded, expanded);
  }

  /// 获取右侧面板展开状态 (默认展开)
  bool getRightPanelExpanded() {
    return getSetting<bool>(
          StorageKeys.rightPanelExpanded,
          defaultValue: true,
        ) ??
        true;
  }

  /// 保存右侧面板展开状态
  Future<void> setRightPanelExpanded(bool expanded) async {
    await setSetting(StorageKeys.rightPanelExpanded, expanded);
  }

  /// 获取左侧面板宽度 (默认300)
  double getLeftPanelWidth() {
    return getSetting<double>(
          StorageKeys.leftPanelWidth,
          defaultValue: 300.0,
        ) ??
        300.0;
  }

  /// 保存左侧面板宽度
  Future<void> setLeftPanelWidth(double width) async {
    await setSetting(StorageKeys.leftPanelWidth, width);
  }

  /// 获取右侧面板宽度 (默认280, 使用 historyPanelWidth key)
  double getRightPanelWidth() {
    return getSetting<double>(
          StorageKeys.historyPanelWidth,
          defaultValue: 280.0,
        ) ??
        280.0;
  }

  /// 保存右侧面板宽度 (使用 historyPanelWidth key)
  Future<void> setRightPanelWidth(double width) async {
    await setSetting(StorageKeys.historyPanelWidth, width);
  }

  /// 获取提示区域高度 (默认200)
  double getPromptAreaHeight() {
    return getSetting<double>(
          StorageKeys.promptAreaHeight,
          defaultValue: 200.0,
        ) ??
        200.0;
  }

  /// 保存提示区域高度
  Future<void> setPromptAreaHeight(double height) async {
    await setSetting(StorageKeys.promptAreaHeight, height);
  }

  /// 获取提示区域最大化状态 (默认关闭)
  bool getPromptMaximized() {
    return getSetting<bool>(
          StorageKeys.promptMaximized,
          defaultValue: false,
        ) ??
        false;
  }

  /// 保存提示区域最大化状态
  Future<void> setPromptMaximized(bool maximized) async {
    await setSetting(StorageKeys.promptMaximized, maximized);
  }

  // ==================== Lifecycle ====================

  /// 关闭存储
  Future<void> close() async {
    await _settingsBox.close();
    await _historyBox.close();
  }

  // ==================== Fixed Tags ====================

  /// 获取固定词列表 JSON
  String? getFixedTagsJson() {
    return getSetting<String>(StorageKeys.fixedTagsData);
  }

  /// 保存固定词列表 JSON
  Future<void> setFixedTagsJson(String json) async {
    await setSetting(StorageKeys.fixedTagsData, json);
  }

  /// 获取固定词分类列表 JSON
  String? getFixedTagCategoriesJson() {
    return getSetting<String>(StorageKeys.fixedTagCategoriesData);
  }

  /// 保存固定词分类列表 JSON
  Future<void> setFixedTagCategoriesJson(String json) async {
    await setSetting(StorageKeys.fixedTagCategoriesData, json);
  }

  // ==================== Tag Library (User) ====================

  /// 获取用户词库条目列表 JSON
  String? getTagLibraryEntriesJson() {
    return getSetting<String>(StorageKeys.tagLibraryEntriesData);
  }

  /// 保存用户词库条目列表 JSON
  Future<void> setTagLibraryEntriesJson(String json) async {
    await setSetting(StorageKeys.tagLibraryEntriesData, json);
  }

  /// 获取用户词库分类列表 JSON
  String? getTagLibraryCategoriesJson() {
    return getSetting<String>(StorageKeys.tagLibraryCategoriesData);
  }

  /// 保存用户词库分类列表 JSON
  Future<void> setTagLibraryCategoriesJson(String json) async {
    await setSetting(StorageKeys.tagLibraryCategoriesData, json);
  }

  /// 获取词库视图模式 (0=card, 1=list)
  int getTagLibraryViewMode() {
    return getSetting<int>(StorageKeys.tagLibraryViewMode) ?? 0;
  }

  /// 保存词库视图模式
  Future<void> setTagLibraryViewMode(int mode) async {
    await setSetting(StorageKeys.tagLibraryViewMode, mode);
  }

  // ==================== Floating Button Background ====================

  /// 获取悬浮球背景图片路径
  String? getFloatingButtonBackgroundImage() {
    return getSetting<String>(StorageKeys.floatingButtonBackgroundImage);
  }

  /// 保存悬浮球背景图片路径
  Future<void> setFloatingButtonBackgroundImage(String? path) async {
    if (path != null) {
      await setSetting(StorageKeys.floatingButtonBackgroundImage, path);
    } else {
      await deleteSetting(StorageKeys.floatingButtonBackgroundImage);
    }
  }
}

/// LocalStorageService Provider
@riverpod
LocalStorageService localStorageService(Ref ref) {
  final service = LocalStorageService();
  // 注意：需要在应用启动时调用 init()
  return service;
}
