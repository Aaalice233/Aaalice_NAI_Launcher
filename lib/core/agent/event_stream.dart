import 'dart:async';

/// EventStream：带最终结果的事件流。
///
/// 生产侧 [push] 事件、[end] 附带结果并关闭；消费侧迭代 [stream] 并以
/// [result] 取最终值。
///
/// 事件流为单订阅模型，订阅建立前
/// 生产的事件会被控制器缓冲而不是丢弃。
class EventStream<E, R> {
  final _events = StreamController<E>();
  final _result = Completer<R>();
  bool _ended = false;

  EventStream();

  /// 以既有事件序列构造（同步包装。
  EventStream.fromEvents(Stream<E> events, Future<R> Function() result) {
    events.listen(
      push,
      onError: (Object error, StackTrace stackTrace) {
        endError(error, stackTrace);
      },
      onDone: () {
        if (!_ended) {
          result().then(end, onError: endError);
        }
      },
    );
  }

  Stream<E> get stream => _events.stream;

  void push(E event) {
    if (_ended) {
      return;
    }
    _events.add(event);
  }

  void end(R result) {
    if (_ended) {
      return;
    }
    _ended = true;
    _result.complete(result);
    _events.close();
  }

  void endError(Object error, [StackTrace? stackTrace]) {
    if (_ended) {
      return;
    }
    _ended = true;
    _result.completeError(error, stackTrace);
    _events.close();
  }

  Future<R> result() => _result.future;
}
