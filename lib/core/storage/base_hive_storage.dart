import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../utils/app_logger.dart';

/// Hive 存储基类
///
/// 提供通用的 Box 管理和 CRUD 操作
/// - [T] 存储的数据类型
/// - 支持懒加载和预打开 Box 两种模式
/// - 支持 JSON 序列化和原始值存储
abstract class BaseHiveStorage<T> {
  /// Box 名称
  final String boxName;

  /// 存储键名（用于单值存储）
  final String? storageKey;

  /// Box 实例（懒加载模式使用）
  Box? _lazyBox;

  /// 是否使用懒加载模式
  final bool useLazyLoading;

  BaseHiveStorage({
    required this.boxName,
    this.storageKey,
    this.useLazyLoading = true,
  });

  /// 获取 Box
  ///
  /// 懒加载模式：异步打开 Box
  /// 预打开模式：同步获取已打开的 Box
  Future<Box> _getBox() async {
    if (!useLazyLoading) {
      throw StateError(
        'Cannot use _getBox() in non-lazy mode. '
        'Access box directly in pre-opened mode.',
      );
    }
    _lazyBox ??= await Hive.openBox(boxName);
    return _lazyBox!;
  }

  /// 获取已打开的 Box（预打开模式使用）
  Box get box {
    if (useLazyLoading) {
      throw StateError(
        'Cannot access box directly in lazy mode. Use _getBox() instead.',
      );
    }
    return Hive.box(boxName);
  }

  /// 保存原始值到指定键
  Future<void> saveRawValue(String key, dynamic value) async {
    if (useLazyLoading) {
      final box = await _getBox();
      await box.put(key, value);
    } else {
      await box.put(key, value);
    }
  }

  /// 加载原始值
  Future<dynamic> loadRawValue(String key, {dynamic defaultValue}) async {
    if (useLazyLoading) {
      final box = await _getBox();
      return box.get(key, defaultValue: defaultValue);
    } else {
      return box.get(key, defaultValue: defaultValue);
    }
  }

  /// 同步加载原始值（预打开模式）
  dynamic loadRawValueSync(String key, {dynamic defaultValue}) {
    if (useLazyLoading) {
      throw StateError('Cannot use sync methods in lazy mode');
    }
    return box.get(key, defaultValue: defaultValue);
  }

  /// 保存 JSON 对象（单值存储模式）
  ///
  /// 将整个对象序列化为 JSON 存储到 [storageKey]
  Future<void> saveAsJson(
    Map<String, dynamic> json, {
    String? key,
  }) async {
    final targetKey = key ?? storageKey;
    if (targetKey == null) {
      throw ArgumentError('storageKey must be provided for JSON storage');
    }

    final jsonString = jsonEncode(json);

    if (useLazyLoading) {
      final box = await _getBox();
      await box.put(targetKey, jsonString);
    } else {
      await box.put(targetKey, jsonString);
    }
  }

  /// 从 JSON 加载（单值存储模式）
  Future<Map<String, dynamic>?> loadFromJson({String? key}) async {
    final targetKey = key ?? storageKey;
    if (targetKey == null) {
      throw ArgumentError('storageKey must be provided for JSON storage');
    }

    try {
      String? jsonString;

      if (useLazyLoading) {
        final box = await _getBox();
        jsonString = box.get(targetKey) as String?;
      } else {
        jsonString = box.get(targetKey) as String?;
      }

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('Failed to load JSON from $boxName/$targetKey', e);
      return null;
    }
  }

  /// 同步从 JSON 加载（预打开模式）
  Map<String, dynamic>? loadFromJsonSync({String? key}) {
    final targetKey = key ?? storageKey;
    if (targetKey == null) {
      throw ArgumentError('storageKey must be provided for JSON storage');
    }

    if (useLazyLoading) {
      throw StateError('Cannot use sync methods in lazy mode');
    }

    try {
      final jsonString = box.get(targetKey) as String?;

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('Failed to load JSON from $boxName/$targetKey', e);
      return null;
    }
  }

  /// 删除指定键
  Future<void> deleteKey(String key) async {
    if (useLazyLoading) {
      final box = await _getBox();
      await box.delete(key);
    } else {
      await box.delete(key);
    }
  }

  /// 清空整个 Box
  Future<void> clear() async {
    if (useLazyLoading) {
      final box = await _getBox();
      await box.clear();
    } else {
      await box.clear();
    }
  }

  /// 关闭 Box（懒加载模式）
  Future<void> close() async {
    if (_lazyBox != null && _lazyBox!.isOpen) {
      await _lazyBox!.close();
      _lazyBox = null;
    }
  }

  /// 获取 Box 长度
  int get length {
    if (useLazyLoading) {
      throw StateError('Cannot get length in lazy mode. Use getLength() instead.');
    }
    return box.length;
  }

  /// 异步获取 Box 长度
  Future<int> getLength() async {
    if (useLazyLoading) {
      final box = await _getBox();
      return box.length;
    } else {
      return box.length;
    }
  }

  /// 获取所有值
  Future<List<dynamic>> getAllValues() async {
    if (useLazyLoading) {
      final box = await _getBox();
      return box.values.toList();
    } else {
      return box.values.toList();
    }
  }

  /// 同步获取所有值（预打开模式）
  List<dynamic> getAllValuesSync() {
    if (useLazyLoading) {
      throw StateError('Cannot use sync methods in lazy mode');
    }
    return box.values.toList();
  }

  /// 保存单个条目（用于键值对存储）
  Future<void> put(String key, dynamic value) async {
    if (useLazyLoading) {
      final box = await _getBox();
      await box.put(key, value);
    } else {
      await box.put(key, value);
    }
  }

  /// 获取单个条目
  Future<dynamic> get(String key, {dynamic defaultValue}) async {
    if (useLazyLoading) {
      final box = await _getBox();
      return box.get(key, defaultValue: defaultValue);
    } else {
      return box.get(key, defaultValue: defaultValue);
    }
  }

  /// 同步获取单个条目
  dynamic getSync(String key, {dynamic defaultValue}) {
    if (useLazyLoading) {
      throw StateError('Cannot use sync methods in lazy mode');
    }
    return box.get(key, defaultValue: defaultValue);
  }

  /// 删除单个条目
  Future<void> delete(String key) async {
    if (useLazyLoading) {
      final box = await _getBox();
      await box.delete(key);
    } else {
      await box.delete(key);
    }
  }
}

/// Hive 存储异常基类
class HiveStorageException implements Exception {
  final String message;
  final Object? originalError;

  HiveStorageException(this.message, {this.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'HiveStorageException: $message (Original: $originalError)';
    }
    return 'HiveStorageException: $message';
  }
}
