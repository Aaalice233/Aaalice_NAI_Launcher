import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/floating_button_position_storage.dart';

part 'floating_button_position_provider.g.dart';

/// 悬浮球位置状态
class FloatingButtonPositionState {
  final double x;
  final double y;
  final bool isFirstLaunch;
  final bool isExpanded;
  final bool isInitialized;

  const FloatingButtonPositionState({
    this.x = 0.0,
    this.y = 0.0,
    this.isFirstLaunch = true,
    this.isExpanded = false,
    this.isInitialized = false,
  });

  FloatingButtonPositionState copyWith({
    double? x,
    double? y,
    bool? isFirstLaunch,
    bool? isExpanded,
    bool? isInitialized,
  }) {
    return FloatingButtonPositionState(
      x: x ?? this.x,
      y: y ?? this.y,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isExpanded: isExpanded ?? this.isExpanded,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// 悬浮球位置管理 Provider
@Riverpod(keepAlive: true)
class FloatingButtonPositionNotifier extends _$FloatingButtonPositionNotifier {
  late final FloatingButtonPositionStorage _storage;

  // 悬浮球尺寸常量
  static const double ballSize = 56.0;
  static const double edgeMargin = 16.0;

  @override
  FloatingButtonPositionState build() {
    _storage = ref.read(floatingButtonPositionStorageProvider);
    _loadFromStorage();
    return const FloatingButtonPositionState();
  }

  /// 从存储加载位置
  Future<void> _loadFromStorage() async {
    final data = await _storage.load();
    state = FloatingButtonPositionState(
      x: data.x,
      y: data.y,
      isFirstLaunch: data.isFirstLaunch,
      isExpanded: data.isExpanded,
      isInitialized: !data.isFirstLaunch,
    );
  }

  /// 初始化位置（首次启动时调用，设置为右下角）
  void initializePosition(Size screenSize) {
    if (state.isInitialized) return;

    // 首次启动，设置在右下角
    final x = screenSize.width - ballSize - edgeMargin;
    final y = screenSize.height - ballSize - edgeMargin - 100; // 留出底部导航空间

    state = state.copyWith(
      x: x,
      y: y,
      isFirstLaunch: false,
      isInitialized: true,
    );

    _storage.savePosition(x, y);
  }

  /// 更新位置（拖拽时调用）
  void updatePosition(double x, double y) {
    state = state.copyWith(x: x, y: y);
  }

  /// 拖拽结束，限制范围并保存位置
  Future<void> snapToEdgeAndSave(Size screenSize) async {
    // 限制 X 轴范围，不强制吸附到边缘
    final minX = edgeMargin;
    final maxX = screenSize.width - ballSize - edgeMargin;
    final newX = state.x.clamp(minX, maxX);

    // 限制 Y 轴范围
    final minY = edgeMargin +
        MediaQueryData.fromView(
          WidgetsBinding.instance.platformDispatcher.views.first,
        ).padding.top;
    final maxY = screenSize.height - ballSize - edgeMargin - 100;
    final newY = state.y.clamp(minY, maxY);

    state = state.copyWith(x: newX, y: newY);
    await _storage.savePosition(newX, newY);
  }

  /// 切换展开/折叠状态
  Future<void> toggleExpanded() async {
    final newExpanded = !state.isExpanded;
    state = state.copyWith(isExpanded: newExpanded);
    await _storage.saveExpandedState(newExpanded);
  }

  /// 设置展开状态
  Future<void> setExpanded(bool expanded) async {
    if (state.isExpanded == expanded) return;
    state = state.copyWith(isExpanded: expanded);
    await _storage.saveExpandedState(expanded);
  }
}
