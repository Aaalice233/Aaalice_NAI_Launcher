import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';

part 'floating_button_position_storage.g.dart';

/// 悬浮球位置数据
class FloatingButtonPositionData {
  final double x;
  final double y;
  final bool isFirstLaunch;
  final bool isExpanded;

  const FloatingButtonPositionData({
    this.x = 0.0,
    this.y = 0.0,
    this.isFirstLaunch = true,
    this.isExpanded = false,
  });

  FloatingButtonPositionData copyWith({
    double? x,
    double? y,
    bool? isFirstLaunch,
    bool? isExpanded,
  }) {
    return FloatingButtonPositionData(
      x: x ?? this.x,
      y: y ?? this.y,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

/// 悬浮球位置存储服务
class FloatingButtonPositionStorage {
  Box<dynamic>? _box;

  /// 获取 Box（懒加载）
  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox(StorageKeys.settingsBox);
    return _box!;
  }

  /// 保存位置
  Future<void> save(FloatingButtonPositionData data) async {
    final box = await _getBox();
    await box.put(StorageKeys.floatingButtonX, data.x);
    await box.put(StorageKeys.floatingButtonY, data.y);
    await box.put(StorageKeys.floatingButtonFirstLaunch, data.isFirstLaunch);
    await box.put(StorageKeys.floatingButtonExpanded, data.isExpanded);
  }

  /// 加载位置
  Future<FloatingButtonPositionData> load() async {
    try {
      final box = await _getBox();
      return FloatingButtonPositionData(
        x: box.get(StorageKeys.floatingButtonX, defaultValue: 0.0) as double,
        y: box.get(StorageKeys.floatingButtonY, defaultValue: 0.0) as double,
        isFirstLaunch: box.get(
          StorageKeys.floatingButtonFirstLaunch,
          defaultValue: true,
        ) as bool,
        isExpanded: box.get(
          StorageKeys.floatingButtonExpanded,
          defaultValue: false,
        ) as bool,
      );
    } catch (e) {
      return const FloatingButtonPositionData();
    }
  }

  /// 仅保存位置（不改变其他状态）
  Future<void> savePosition(double x, double y) async {
    final box = await _getBox();
    await box.put(StorageKeys.floatingButtonX, x);
    await box.put(StorageKeys.floatingButtonY, y);
    await box.put(StorageKeys.floatingButtonFirstLaunch, false);
  }

  /// 仅保存展开状态
  Future<void> saveExpandedState(bool isExpanded) async {
    final box = await _getBox();
    await box.put(StorageKeys.floatingButtonExpanded, isExpanded);
  }
}

/// 悬浮球位置存储服务 Provider
@riverpod
FloatingButtonPositionStorage floatingButtonPositionStorage(Ref ref) {
  return FloatingButtonPositionStorage();
}
