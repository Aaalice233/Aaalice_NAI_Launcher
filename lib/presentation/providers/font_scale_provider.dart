import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'font_scale_provider.g.dart';

/// 字体缩放状态 Notifier
@riverpod
class FontScaleNotifier extends _$FontScaleNotifier {
  /// 默认字体缩放比例
  static const double defaultScale = 1.0;

  /// 最小字体缩放比例
  static const double minScale = 0.8;

  /// 最大字体缩放比例
  static const double maxScale = 1.5;

  /// 步长
  static const double step = 0.1;

  @override
  double build() {
    final storage = ref.read(localStorageServiceProvider);
    return storage.getFontScale();
  }

  /// 设置字体缩放比例
  ///
  /// 自动限制在范围内并按步长对齐
  Future<void> setFontScale(double scale) async {
    // 限制范围
    var clampedScale = scale.clamp(minScale, maxScale);

    // 按步长对齐
    final steps = ((clampedScale - minScale) / step).round();
    clampedScale = minScale + steps * step;

    // 再次确保在范围内（处理浮点精度问题）
    clampedScale = clampedScale.clamp(minScale, maxScale);

    // 更新状态
    state = clampedScale;

    // 持久化到存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFontScale(clampedScale);
  }

  /// 重置为默认值
  Future<void> reset() async {
    await setFontScale(defaultScale);
  }
}
