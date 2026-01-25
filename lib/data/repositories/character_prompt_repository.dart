import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/character/character_prompt.dart';

part 'character_prompt_repository.g.dart';

/// 多角色提示词数据仓库
///
/// 负责 CharacterPromptConfig 的持久化存储和读取。
/// 使用 Hive 进行本地存储，数据以 JSON 格式序列化。
///
/// Requirements: 1.4
class CharacterPromptRepository {
  /// 存储键
  static const String _configKey = 'character_prompt_config';

  /// 获取 settings box
  Box get _box => Hive.box(StorageKeys.settingsBox);

  /// 加载角色提示词配置
  ///
  /// 从本地存储加载配置，如果不存在或解析失败则返回默认空配置。
  ///
  /// Returns: [CharacterPromptConfig] 角色提示词配置
  CharacterPromptConfig load() {
    try {
      final configJson = _box.get(_configKey) as String?;

      if (configJson == null || configJson.isEmpty) {
        AppLogger.d(
          'No character prompt config found, using default',
          'CharacterPromptRepo',
        );
        return const CharacterPromptConfig();
      }

      final decoded = jsonDecode(configJson) as Map<String, dynamic>;
      final config = CharacterPromptConfig.fromJson(decoded);
      AppLogger.d(
        'Loaded character prompt config with ${config.characters.length} characters',
        'CharacterPromptRepo',
      );
      return config;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load character prompt config: $e',
        e,
        stack,
        'CharacterPromptRepo',
      );
      // 加载失败时返回默认空配置
      return const CharacterPromptConfig();
    }
  }

  /// 保存角色提示词配置
  ///
  /// 将配置序列化为 JSON 并保存到本地存储。
  ///
  /// [config] 要保存的配置
  ///
  /// Returns: [bool] 保存是否成功
  Future<bool> save(CharacterPromptConfig config) async {
    try {
      final json = jsonEncode(config.toJson());
      await _box.put(_configKey, json);
      AppLogger.d(
        'Saved character prompt config with ${config.characters.length} characters',
        'CharacterPromptRepo',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save character prompt config: $e',
        e,
        stack,
        'CharacterPromptRepo',
      );
      return false;
    }
  }

  /// 清除角色提示词配置
  ///
  /// 从本地存储中删除配置数据。
  ///
  /// Returns: [bool] 清除是否成功
  Future<bool> clear() async {
    try {
      await _box.delete(_configKey);
      AppLogger.d('Cleared character prompt config', 'CharacterPromptRepo');
      return true;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to clear character prompt config: $e',
        e,
        stack,
        'CharacterPromptRepo',
      );
      return false;
    }
  }

  /// 检查是否存在已保存的配置
  ///
  /// Returns: [bool] 是否存在配置
  bool hasConfig() {
    return _box.containsKey(_configKey);
  }
}

/// CharacterPromptRepository Provider
@riverpod
CharacterPromptRepository characterPromptRepository(Ref ref) {
  return CharacterPromptRepository();
}
