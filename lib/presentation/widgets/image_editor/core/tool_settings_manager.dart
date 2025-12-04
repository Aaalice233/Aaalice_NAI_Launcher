import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 工具设置管理器
/// 独立存储各工具的设置，支持持久化到本地存储
class ToolSettingsManager {
  /// SharedPreferences 存储键
  static const String _storageKey = 'image_editor_tool_settings';

  /// 工具设置缓存
  final Map<String, Map<String, dynamic>> _settingsCache = {};

  /// 是否已从存储加载
  bool _isLoaded = false;

  /// 获取工具设置
  /// 使用类型检查而非强制转换，避免 TypeError
  T? getSetting<T>(String toolId, String key) {
    final value = _settingsCache[toolId]?[key];
    return value is T ? value : null;
  }

  /// 设置工具设置
  void setSetting<T>(String toolId, String key, T value) {
    _settingsCache[toolId] ??= {};
    _settingsCache[toolId]![key] = value;
  }

  /// 获取工具的所有设置
  Map<String, dynamic>? getToolSettings(String toolId) {
    return _settingsCache[toolId];
  }

  /// 恢复工具设置
  void restoreToolSettings(String toolId, Map<String, dynamic> settings) {
    _settingsCache[toolId] = Map.from(settings);
  }

  /// 导出所有设置（用于持久化）
  Map<String, dynamic> exportAll() {
    return Map.from(_settingsCache);
  }

  /// 导入设置
  void importAll(Map<String, dynamic> data) {
    _settingsCache.clear();
    data.forEach((toolId, settings) {
      if (settings is Map<String, dynamic>) {
        _settingsCache[toolId] = Map.from(settings);
      }
    });
  }

  /// 从本地存储加载设置
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final data = json.decode(jsonString) as Map<String, dynamic>;
        importAll(data);
      }

      _isLoaded = true;
    } catch (e) {
      // 加载失败时使用默认设置
      _isLoaded = true;
    }
  }

  /// 保存设置到本地存储
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(exportAll());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // 保存失败时静默处理
    }
  }

  /// 清除所有设置
  Future<void> clear() async {
    _settingsCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      // 清除失败时静默处理
    }
  }
}
