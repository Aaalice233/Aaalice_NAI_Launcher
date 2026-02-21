import 'dart:async';

import 'package:flutter/foundation.dart';

/// 防抖器
/// 用于限制函数调用频率，在指定延迟时间内只执行最后一次调用
class Debouncer {
  /// 防抖延迟
  final Duration delay;

  /// 防抖计时器
  Timer? _timer;

  /// 是否正在等待执行
  bool get isWaiting => _timer?.isActive ?? false;

  Debouncer({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行防抖操作
  /// [action] 要执行的回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  void run(VoidCallback action, {bool immediate = false}) {
    _timer?.cancel();

    if (immediate) {
      action();
    } else {
      _timer = Timer(delay, action);
    }
  }

  /// 取消待执行的防抖操作
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 刷新防抖计时器
  /// 重置延迟时间，如果已有待执行操作则重新计时
  void refresh() {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      // 注意：刷新计时器需要重新调用 run 方法传入 action
      // 此方法主要用于需要延长等待时间的场景
    }
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 带参数的防抖器
/// 支持传递一个参数的防抖操作
class DebouncerWithArg<T> {
  /// 防抖延迟
  final Duration delay;

  /// 防抖计时器
  Timer? _timer;

  /// 待执行的回调
  void Function(T)? _pendingAction;

  /// 是否正在等待执行
  bool get isWaiting => _timer?.isActive ?? false;

  DebouncerWithArg({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行防抖操作
  /// [arg] 传递给回调函数的参数
  /// [action] 要执行的回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  void run(T arg, void Function(T) action, {bool immediate = false}) {
    _timer?.cancel();
    _pendingAction = action;

    if (immediate) {
      action(arg);
      _pendingAction = null;
    } else {
      _timer = Timer(delay, () {
        _pendingAction?.call(arg);
        _pendingAction = null;
      });
    }
  }

  /// 取消待执行的防抖操作
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
  }

  /// 释放资源
  void dispose() {
    cancel();
  }
}

/// 异步防抖器
/// 支持异步操作的防抖
class AsyncDebouncer<T> {
  /// 防抖延迟
  final Duration delay;

  /// 防抖计时器
  Timer? _timer;

  /// 是否正在等待执行
  bool get isWaiting => _timer?.isActive ?? false;

  AsyncDebouncer({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行异步防抖操作
  /// [action] 要执行的异步回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  Future<T> run(Future<T> Function() action, {bool immediate = false}) async {
    _timer?.cancel();

    if (immediate) {
      return await action();
    } else {
      final completer = Completer<T>();

      _timer = Timer(delay, () async {
        try {
          final result = await action();
          completer.complete(result);
        } catch (e, stackTrace) {
          completer.completeError(e, stackTrace);
        }
      });

      return completer.future;
    }
  }

  /// 取消待执行的防抖操作
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源
  void dispose() {
    cancel();
  }
}
