import 'dart:convert';


/// 可失败操作的结果。预期失败以 `ok: false` 返回而不是抛出。
sealed class HarnessResult<TValue, TError extends Object> {
  const HarnessResult();
}

class HarnessOk<TValue, TError extends Object> extends HarnessResult<TValue, TError> {
  const HarnessOk(this.value);

  final TValue value;
}

class HarnessErr<TValue, TError extends Object> extends HarnessResult<TValue, TError> {
  const HarnessErr(this.error);

  final TError error;
}

extension HarnessResultX<TValue, TError extends Object>
    on HarnessResult<TValue, TError> {
  /// 成功值；失败结果返回 null。
  TValue? get valueOrNull =>
      this is HarnessOk<TValue, TError>
          ? (this as HarnessOk<TValue, TError>).value
          : null;

  /// 失败错误；成功结果返回 null。
  TError? get errorOrNull =>
      this is HarnessErr<TValue, TError>
          ? (this as HarnessErr<TValue, TError>).error
          : null;
}

/// 创建成功结果。
HarnessResult<TValue, TError> ok<TValue, TError extends Object>(TValue value) {
  return HarnessOk(value);
}

/// 创建失败结果。
HarnessResult<TValue, TError> err<TValue, TError extends Object>(TError error) {
  return HarnessErr(error);
}

/// 返回成功值或抛出失败错误。用于测试与显式适配边界。
TValue getOrThrow<TValue, TError extends Object>(
  HarnessResult<TValue, TError> result,
) {
  if (result is HarnessOk<TValue, TError>) {
    return result.value;
  }
  if (result is HarnessErr<TValue, TError>) {
    throw result.error;
  }
  throw StateError('unreachable');
}

/// 返回成功值或 null。
TValue? getOrUndefined<TValue extends Object, TError extends Object>(
  HarnessResult<TValue, TError> result,
) {
  return result.valueOrNull;
}

/// 把未知抛出值归一化为 Error。
Object toError(Object error) {
  if (error is Error) {
    return error;
  }
  if (error is String) {
    return StateError(error);
  }
  try {
    return StateError(jsonEncode(error));
  } catch (_) {
    return StateError(error.toString());
  }
}

/// 带标签的错误基类：`_tag` 判别 + props 混入 +
/// toJSON 序列化。
abstract class TaggedErrorBase implements Exception {
  const TaggedErrorBase(this.message);

  final String message;

  /// 判别标签（子类返回类名常量）。
  String get tag;

  /// 附加属性（子类覆写），参与 toJSON。
  Map<String, dynamic> props() => const {};

  Map<String, dynamic> toJson() => {
    '_tag': tag,
    'message': message,
    ...props(),
  };

  @override
  String toString() => '$tag: $message';
}

/// 按 tag 对 TaggedError 分派。
TValue matchTaggedError<TValue>(
  TaggedErrorBase error,
  Map<String, TValue Function(TaggedErrorBase error)> matchers,
) {
  final matcher = matchers[error.tag];
  if (matcher == null) {
    throw error;
  }
  return matcher(error);
}
