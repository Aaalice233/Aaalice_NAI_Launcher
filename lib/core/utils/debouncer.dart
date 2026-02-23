import 'dart:async';

import 'package:flutter/foundation.dart';

/// 防抖器基础功能 Mixin
/// 提供防抖的核心逻辑，避免代码重复
mixin _DebouncerBase {
  /// 防抖延迟
  Duration get delay;

  /// 防抖计时器
  Timer? get timer;
  set timer(Timer? value);

  /// 是否正在等待执行
  bool get isWaiting => timer?.isActive ?? false;

  /// 取消待执行的防抖操作
  void cancel() {
    timer?.cancel();
    timer = null;
  }

  /// 释放资源
  void dispose() {
    cancel();
  }
}

/// 防抖器
/// 用于限制函数调用频率，在指定延迟时间内只执行最后一次调用
class Debouncer with _DebouncerBase {
  @override
  final Duration delay;

  @override
  Timer? timer;

  Debouncer({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行防抖操作
  /// [action] 要执行的回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  void run(VoidCallback action, {bool immediate = false}) {
    cancel();

    if (immediate) {
      action();
    } else {
      timer = Timer(delay, action);
    }
  }

  /// 刷新防抖计时器
  /// 重置延迟时间，如果已有待执行操作则重新计时
  /// [action] 要重新执行的回调函数
  void refresh(VoidCallback action) {
    if (isWaiting) {
      run(action);
    }
  }
}

/// 带参数的防抖器
/// 支持传递一个参数的防抖操作
class DebouncerWithArg<T> with _DebouncerBase {
  @override
  final Duration delay;

  @override
  Timer? timer;

  /// 待执行的回调
  void Function(T)? _pendingAction;

  DebouncerWithArg({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行防抖操作
  /// [arg] 传递给回调函数的参数
  /// [action] 要执行的回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  void run(T arg, void Function(T) action, {bool immediate = false}) {
    cancel();
    _pendingAction = action;

    if (immediate) {
      action(arg);
      _pendingAction = null;
    } else {
      timer = Timer(delay, () {
        _pendingAction?.call(arg);
        _pendingAction = null;
      });
    }
  }

  @override
  void cancel() {
    super.cancel();
    _pendingAction = null;
  }
}

/// 异步防抖器
/// 支持异步操作的防抖
class AsyncDebouncer<T> with _DebouncerBase {
  @override
  final Duration delay;

  @override
  Timer? timer;

  /// 当前待处理的 completer，用于在取消时完成它
  Completer<T>? _pendingCompleter;

  AsyncDebouncer({
    this.delay = const Duration(milliseconds: 300),
  });

  /// 执行异步防抖操作
  /// [action] 要执行的异步回调函数
  /// [immediate] 是否立即执行（跳过防抖，默认为 false）
  Future<T> run(Future<T> Function() action, {bool immediate = false}) async {
    cancel();

    if (immediate) {
      return await action();
    } else {
      final completer = Completer<T>();
      _pendingCompleter = completer;

      timer = Timer(delay, () async {
        // 清除 pending completer 引用
        _pendingCompleter = null;
        try {
          final result = await action();
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        } catch (e, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(e, stackTrace);
          }
        }
      });

      return completer.future;
    }
  }

  @override
  void cancel() {
    // 如果有待处理的 completer，用错误完成它以避免 orphaned future
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(
        StateError('Debouncer cancelled before action could execute'),
      );
      _pendingCompleter = null;
    }
    super.cancel();
  }

  @override
  void dispose() {
    cancel();
  }
}
