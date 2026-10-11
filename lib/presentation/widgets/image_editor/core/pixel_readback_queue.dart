import '../../../../core/utils/app_logger.dart';

/// 需要先异步回读像素才能写回的编辑按提交顺序逐个执行，后一次总是基于前一次写回后的画面
class PixelReadbackQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _closed = false;

  bool get isIdle => _pending == 0;

  /// 此刻已排队的编辑全部结束后完成
  Future<void> get idle => _tail;

  /// 排在已有编辑之后执行；单次编辑失败只记录，不阻断后续编辑
  Future<void> run(Future<void> Function() edit) {
    _pending++;
    return _tail = _tail
        .then((_) async {
          if (!_closed) await edit();
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.e(
            'Pixel readback edit failed',
            error,
            stackTrace,
            'ImageEditor',
          );
        })
        .whenComplete(() {
          _pending--;
        });
  }

  /// 编辑器关闭后尚未开始的编辑不再执行
  void close() => _closed = true;
}
