import 'dart:async';
import 'dart:typed_data';

class DerivativeRenderCancelledException implements Exception {
  const DerivativeRenderCancelledException();

  @override
  String toString() => 'DerivativeRenderCancelledException';
}

/// 渲染流程在检查点调用 [throwIfCancelled]；等待渲染的一方用 [race] 在取消时立即脱身。
class DerivativeRenderCancellationToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const DerivativeRenderCancelledException();
  }

  /// 取消时立即以 [DerivativeRenderCancelledException] 结束；被放弃的 [work] 照常跑完，结果与错误都被丢弃。
  Future<T> race<T>(Future<T> work) {
    if (isCancelled) {
      work.ignore();
      return Future<T>.error(const DerivativeRenderCancelledException());
    }
    return Future.any<T>([
      work,
      whenCancelled.then<T>(
        (_) => throw const DerivativeRenderCancelledException(),
      ),
    ]);
  }
}

/// 写入图库前的最终副本。
abstract interface class DerivativeRenderedCopy {
  Uint8List get bytes;
  String get fileName;
}
