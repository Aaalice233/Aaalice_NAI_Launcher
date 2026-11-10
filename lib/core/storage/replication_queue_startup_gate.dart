import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

/// 启动期队列索引的读取闸门：应用入口挂载界面前关闭，启动迁移结束后打开。
///
/// 从未关闭时（测试、工具）不做限制。
abstract final class ReplicationQueueStartupGate {
  static _GateState _state = _GateState.unguarded;
  static bool _readWhileClosed = false;

  static void close() => _state = _GateState.closed;

  /// 迁移成功或失败都要调用，失败时索引保持原样可读。
  static void open() => _state = _GateState.open;

  static bool get isOpen => _state != _GateState.closed;

  /// 本进程内有人在闸门关闭期间读过索引。
  ///
  /// 读到的可能是迁移前的旧索引，内存里没有迁移生成的图片引用，本进程内任何清扫的
  /// 根集合都不可信；一次成功保存也改变不了另一份索引仍引用这些图片，所以不清除。
  static bool get readWhileClosed => _readWhileClosed;

  /// 在读取队列或失败池索引之前调用。
  ///
  /// debug 下直接断言失败；release 下只记日志继续读取：抛出会让队列以空状态启动，
  /// 下一次保存就会用空列表覆盖磁盘上的任务。
  static void checkReadable(String reader) {
    if (isOpen) return;
    _readWhileClosed = true;
    AppLogger.e(
      'Queue index read before the startup migration finished',
      reader,
      null,
      'QueueStartup',
    );
    assert(false, '$reader read the queue index before migration finished');
  }

  @visibleForTesting
  static void reset() {
    _state = _GateState.unguarded;
    _readWhileClosed = false;
  }
}

enum _GateState { unguarded, closed, open }
