import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_subscription.freezed.dart';
part 'user_subscription.g.dart';

/// 用户订阅信息模型
///
/// 从 /user/subscription API 获取，包含订阅等级和 Anlas 余额信息
@freezed
class UserSubscription with _$UserSubscription {
  const UserSubscription._();

  const factory UserSubscription({
    /// 订阅等级 (0=Paper, 1=Tablet, 2=Scroll, 3=Opus)
    @Default(0) int tier,

    /// 是否激活
    @Default(false) bool active,

    /// 订阅到期时间（Unix 时间戳秒）
    int? expiresAt,

    /// Anlas 余额信息
    TrainingStepsInfo? trainingStepsLeft,

    /// 订阅权益信息
    SubscriptionPerks? perks,

    /// 账户类型
    int? accountType,

    /// 是否在宽限期
    @Default(false) bool isGracePeriod,
  }) = _UserSubscription;

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      _$UserSubscriptionFromJson(json);

  /// 是否是 Opus 订阅
  bool get isOpus => tier == 3;

  /// 当前 Anlas 余额（固定 + 购买）
  int get anlasBalance {
    if (trainingStepsLeft == null) return 0;
    return trainingStepsLeft!.fixedTrainingStepsLeft +
        trainingStepsLeft!.purchasedTrainingSteps;
  }

  /// 订阅等级名称
  String get tierName {
    switch (tier) {
      case 0:
        return 'Paper';
      case 1:
        return 'Tablet';
      case 2:
        return 'Scroll';
      case 3:
        return 'Opus';
      default:
        return 'Unknown';
    }
  }
}

/// Anlas 训练步数信息
@freezed
class TrainingStepsInfo with _$TrainingStepsInfo {
  const factory TrainingStepsInfo({
    /// 固定（每月重置）的 Anlas
    @Default(0) int fixedTrainingStepsLeft,

    /// 购买的 Anlas（不重置）
    @Default(0) int purchasedTrainingSteps,
  }) = _TrainingStepsInfo;

  factory TrainingStepsInfo.fromJson(Map<String, dynamic> json) =>
      _$TrainingStepsInfoFromJson(json);
}

/// 订阅权益信息
@freezed
class SubscriptionPerks with _$SubscriptionPerks {
  const factory SubscriptionPerks({
    /// 最大优先级动作数
    @Default(0) int maxPriorityActions,

    /// 起始优先级
    @Default(0) int startPriority,

    /// 模块训练步数
    @Default(0) int moduleTrainingSteps,

    /// 是否有无限最大优先级
    @Default(false) bool unlimitedMaxPriority,

    /// 是否可语音生成
    @Default(false) bool voiceGeneration,

    /// 是否可图像生成
    @Default(false) bool imageGeneration,

    /// 是否有无限图像生成
    @Default(false) bool unlimitedImageGeneration,

    /// 无限图像生成限制
    List<ImageGenerationLimit>? unlimitedImageGenerationLimits,

    /// 上下文 Token 数量
    @Default(0) int contextTokens,
  }) = _SubscriptionPerks;

  factory SubscriptionPerks.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPerksFromJson(json);
}

/// 图像生成限制
@freezed
class ImageGenerationLimit with _$ImageGenerationLimit {
  const factory ImageGenerationLimit({
    /// 分辨率（像素数）
    @Default(0) int resolution,

    /// 最大提示数
    @Default(0) int maxPrompts,
  }) = _ImageGenerationLimit;

  factory ImageGenerationLimit.fromJson(Map<String, dynamic> json) =>
      _$ImageGenerationLimitFromJson(json);
}

/// 订阅状态
@freezed
class SubscriptionState with _$SubscriptionState {
  const SubscriptionState._();

  /// 初始状态
  const factory SubscriptionState.initial() = SubscriptionStateInitial;

  /// 加载中
  const factory SubscriptionState.loading() = SubscriptionStateLoading;

  /// 加载成功
  const factory SubscriptionState.loaded(UserSubscription subscription) =
      SubscriptionStateLoaded;

  /// 加载失败
  const factory SubscriptionState.error(String message) = SubscriptionStateError;

  /// 获取订阅信息（如果已加载）
  UserSubscription? get subscription => maybeMap(
        loaded: (state) => state.subscription,
        orElse: () => null,
      );

  /// 是否正在加载
  bool get isLoading => maybeMap(
        loading: (_) => true,
        orElse: () => false,
      );

  /// 余额（如果已加载）
  int? get balance => subscription?.anlasBalance;

  /// 是否 Opus（如果已加载）
  bool get isOpus => subscription?.isOpus ?? false;
}
