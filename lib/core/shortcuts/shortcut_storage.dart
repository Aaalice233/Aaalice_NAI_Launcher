import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'shortcut_config.dart';

/// 快捷键存储服务
/// 负责快捷键配置的持久化存储
class ShortcutStorage {
  static const String _boxName = 'shortcuts';
  static const String _configKey = 'shortcut_config';

  // 单例实例
  static final ShortcutStorage _instance = ShortcutStorage._internal();

  factory ShortcutStorage() => _instance;

  ShortcutStorage._internal({
    Future<String?> Function()? readConfigOverride,
    Future<void> Function(String value)? writeConfigOverride,
  }) : _readConfigOverride = readConfigOverride,
       _writeConfigOverride = writeConfigOverride;

  @visibleForTesting
  ShortcutStorage.forTesting({
    required Future<String?> Function() readConfig,
    required Future<void> Function(String value) writeConfig,
  }) : this._internal(
         readConfigOverride: readConfig,
         writeConfigOverride: writeConfig,
       );

  Box? _box;
  bool _initialized = false;
  final Future<String?> Function()? _readConfigOverride;
  final Future<void> Function(String value)? _writeConfigOverride;

  /// 初始化存储
  Future<void> init() async {
    if (_initialized && _box != null && _box!.isOpen) {
      return;
    }

    try {
      _box = await Hive.openBox(_boxName);
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to open shortcuts box: $e');
      // 如果打开失败，尝试删除并重新创建
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox(_boxName);
      _initialized = true;
    }
  }

  /// 获取存储实例（自动初始化）
  Future<Box> get _safeBox async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  /// 加载快捷键配置
  /// 如果没有保存的配置，返回默认配置
  Future<ShortcutConfig> loadConfig() async {
    late final ShortcutConfig loaded;
    try {
      final jsonString = await _readConfigString();
      if (jsonString == null || jsonString.isEmpty) {
        return ShortcutConfig.createDefault();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      loaded = ShortcutConfig.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load shortcut config: $e');
      return ShortcutConfig.createDefault();
    }

    final merged = loaded.mergedWithDefaults();
    if (merged != loaded) {
      try {
        await saveConfig(merged);
      } catch (e) {
        debugPrint('Failed to persist merged shortcut config: $e');
      }
    }
    return merged;
  }

  /// 保存快捷键配置
  Future<void> saveConfig(ShortcutConfig config) async {
    try {
      final json = config.toJson();
      final jsonString = jsonEncode(json);
      await _writeConfigString(jsonString);
    } catch (e) {
      debugPrint('Failed to save shortcut config: $e');
      rethrow;
    }
  }

  /// 重置为默认配置
  Future<ShortcutConfig> resetToDefault() async {
    final defaultConfig = ShortcutConfig.createDefault();
    await saveConfig(defaultConfig);
    return defaultConfig;
  }

  /// 导出配置为JSON字符串
  Future<String> exportConfig() async {
    final config = await loadConfig();
    final json = config.toJson();
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// 从JSON字符串导入配置
  Future<ShortcutConfig> importConfig(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final config = ShortcutConfig.fromJson(json).mergedWithDefaults();
      await saveConfig(config);
      return config;
    } catch (e) {
      debugPrint('Failed to import shortcut config: $e');
      throw FormatException('Invalid shortcut config format: $e');
    }
  }

  /// 关闭存储
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _box = null;
    _initialized = false;
  }

  /// 清除所有数据
  Future<void> clear() async {
    final box = await _safeBox;
    await box.clear();
  }

  Future<String?> _readConfigString() async {
    final override = _readConfigOverride;
    if (override != null) return override();
    final box = await _safeBox;
    return box.get(_configKey) as String?;
  }

  Future<void> _writeConfigString(String value) async {
    final override = _writeConfigOverride;
    if (override != null) return override(value);
    final box = await _safeBox;
    await box.put(_configKey, value);
  }
}

/// 快捷键存储Provider（用于Riverpod）
/// 注意：实际Provider定义在presentation/providers/shortcuts_provider.dart
