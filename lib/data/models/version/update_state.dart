import 'package:freezed_annotation/freezed_annotation.dart';

import 'version_info.dart';

part 'update_state.freezed.dart';

/// 更新状态联合类型
@freezed
sealed class UpdateState with _$UpdateState {
  /// 空闲状态
  const factory UpdateState.idle() = UpdateStateIdle;

  /// 检查中状态
  const factory UpdateState.checking() = UpdateStateChecking;

  /// 有可用更新
  const factory UpdateState.available(VersionInfo info) = UpdateStateAvailable;

  /// 已是最新版本
  const factory UpdateState.upToDate() = UpdateStateUpToDate;

  /// 错误状态
  const factory UpdateState.error(String message) = UpdateStateError;

  const UpdateState._();

  /// 是否正在检查更新
  bool get isChecking => maybeWhen(
        checking: () => true,
        orElse: () => false,
      );

  /// 是否有可用更新
  bool get hasUpdate => maybeWhen(
        available: (_) => true,
        orElse: () => false,
      );

  /// 是否发生错误
  bool get isError => maybeWhen(
        error: (_) => true,
        orElse: () => false,
      );
}
