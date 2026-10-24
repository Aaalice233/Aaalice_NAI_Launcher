import 'dart:math' as math;

/// 决定子树要稳定多少帧才值得截图缓存。
///
/// 截图要完整渲染一次子树；缓存还没回本就作废时加倍门槛，长期有效后再降回基线。
class RasterCachePromotionPolicy {
  RasterCachePromotionPolicy({
    this.baseStableFrames = 6,
    this.maxStableFrames = 120,
    this.provenDisplayedFrames = 240,
  }) : assert(baseStableFrames > 0),
       assert(maxStableFrames >= baseStableFrames),
       _stableFramesRequired = baseStableFrames;

  final int baseStableFrames;
  final int maxStableFrames;

  /// 缓存连续展示这么多帧后视为该区域确实稳定。
  final int provenDisplayedFrames;

  int _stableFramesRequired;

  int get stableFramesRequired => _stableFramesRequired;

  void recordEviction({required int displayedFrames}) {
    if (displayedFrames >= provenDisplayedFrames) {
      _stableFramesRequired = baseStableFrames;
    } else if (displayedFrames < _stableFramesRequired) {
      _backOff();
    }
  }

  /// 位置或尺寸暂时不满足缓存条件，推迟下一次尝试。
  void recordRejectedAttempt() => _backOff();

  void _backOff() {
    _stableFramesRequired = math.min(
      _stableFramesRequired * 2,
      maxStableFrames,
    );
  }
}
