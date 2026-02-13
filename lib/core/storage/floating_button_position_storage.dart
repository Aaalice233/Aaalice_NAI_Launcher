import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import 'base_hive_storage.dart';

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
class FloatingButtonPositionStorage extends BaseHiveStorage<void> {
  FloatingButtonPositionStorage()
    : super(boxName: StorageKeys.settingsBox, useLazyLoading: true);

  /// 保存位置
  Future<void> save(FloatingButtonPositionData data) async {
    await saveRawValue(StorageKeys.floatingButtonX, data.x);
    await saveRawValue(StorageKeys.floatingButtonY, data.y);
    await saveRawValue(StorageKeys.floatingButtonFirstLaunch, data.isFirstLaunch);
    await saveRawValue(StorageKeys.floatingButtonExpanded, data.isExpanded);
  }

  /// 加载位置
  Future<FloatingButtonPositionData> load() async {
    try {
      return FloatingButtonPositionData(
        x: await loadRawValue(StorageKeys.floatingButtonX, defaultValue: 0.0) as double,
        y: await loadRawValue(StorageKeys.floatingButtonY, defaultValue: 0.0) as double,
        isFirstLaunch: await loadRawValue(
          StorageKeys.floatingButtonFirstLaunch,
          defaultValue: true,
        ) as bool,
        isExpanded: await loadRawValue(
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
    await saveRawValue(StorageKeys.floatingButtonX, x);
    await saveRawValue(StorageKeys.floatingButtonY, y);
    await saveRawValue(StorageKeys.floatingButtonFirstLaunch, false);
  }

  /// 仅保存展开状态
  Future<void> saveExpandedState(bool isExpanded) async {
    await saveRawValue(StorageKeys.floatingButtonExpanded, isExpanded);
  }
}

/// 悬浮球位置存储服务 Provider
@riverpod
FloatingButtonPositionStorage floatingButtonPositionStorage(Ref ref) {
  return FloatingButtonPositionStorage();
}
