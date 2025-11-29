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
    return getSetting<String>(StorageKeys.fontFamily, defaultValue: 'system') ?? 'system';
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
    return getSetting<String>(StorageKeys.defaultModel, defaultValue: 'nai-diffusion-3') ??
        'nai-diffusion-3';
  }

  /// 保存默认模型
  Future<void> setDefaultModel(String model) async {
    await setSetting(StorageKeys.defaultModel, model);
  }

  /// 获取默认采样器
  String getDefaultSampler() {
    return getSetting<String>(StorageKeys.defaultSampler, defaultValue: 'k_euler_ancestral') ??
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
    return getSetting<double>(StorageKeys.defaultScale, defaultValue: 5.0) ?? 5.0;
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
    return getSetting<int>(StorageKeys.defaultHeight, defaultValue: 1216) ?? 1216;
  }

  /// 保存默认高度
  Future<void> setDefaultHeight(int height) async {
    await setSetting(StorageKeys.defaultHeight, height);
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
    return getSetting<bool>(StorageKeys.autoSaveImages, defaultValue: false) ?? false;
  }

  /// 保存是否自动保存图片
  Future<void> setAutoSaveImages(bool value) async {
    await setSetting(StorageKeys.autoSaveImages, value);
  }

  // ==================== Quality Tags ====================

  /// 获取是否添加质量标签 (默认开启)
  bool getAddQualityTags() {
    return getSetting<bool>(StorageKeys.addQualityTags, defaultValue: true) ?? true;
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

  // ==================== Random Prompt Mode ====================

  /// 获取抽卡模式 (默认关闭)
  bool getRandomPromptMode() {
    return getSetting<bool>(StorageKeys.randomPromptMode, defaultValue: false) ?? false;
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
    return getSetting<bool>(StorageKeys.enableAutocomplete, defaultValue: true) ?? true;
  }

  /// 保存是否启用自动补全
  Future<void> setEnableAutocomplete(bool value) async {
    await setSetting(StorageKeys.enableAutocomplete, value);
  }

  // ==================== Auto Format ====================

  /// 获取是否启用自动格式化 (默认开启)
  bool getAutoFormatPrompt() {
    return getSetting<bool>(StorageKeys.autoFormatPrompt, defaultValue: true) ?? true;
  }

  /// 保存是否启用自动格式化
  Future<void> setAutoFormatPrompt(bool value) async {
    await setSetting(StorageKeys.autoFormatPrompt, value);
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
    return getSetting<String>(StorageKeys.lastNegativePrompt, defaultValue: '') ?? '';
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
    return getSetting<bool>(StorageKeys.lastSmeaDyn, defaultValue: false) ?? false;
  }

  /// 保存 SMEA DYN 设置
  Future<void> setLastSmeaDyn(bool smeaDyn) async {
    await setSetting(StorageKeys.lastSmeaDyn, smeaDyn);
  }

  /// 获取上次的 CFG Rescale 值
  double getLastCfgRescale() {
    return getSetting<double>(StorageKeys.lastCfgRescale, defaultValue: 0.0) ?? 0.0;
  }

  /// 保存 CFG Rescale 值
  Future<void> setLastCfgRescale(double cfgRescale) async {
    await setSetting(StorageKeys.lastCfgRescale, cfgRescale);
  }

  /// 获取上次的噪声计划
  String getLastNoiseSchedule() {
    return getSetting<String>(StorageKeys.lastNoiseSchedule, defaultValue: 'native') ?? 'native';
  }

  /// 保存噪声计划
  Future<void> setLastNoiseSchedule(String noiseSchedule) async {
    await setSetting(StorageKeys.lastNoiseSchedule, noiseSchedule);
  }

  // ==================== Lifecycle ====================

  /// 关闭存储
  Future<void> close() async {
    await _settingsBox.close();
    await _historyBox.close();
  }
}

/// LocalStorageService Provider
@riverpod
LocalStorageService localStorageService(Ref ref) {
  final service = LocalStorageService();
  // 注意：需要在应用启动时调用 init()
  return service;
}
