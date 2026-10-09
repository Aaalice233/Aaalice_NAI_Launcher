import 'dart:async';
import 'dart:io';
import 'dart:ui';

/// 修正 Windows 剪贴板历史粘贴生成的异常按键序列。
///
/// Windows 11 从 Win+V 面板选择内容后，会用扫描码为 0 的消息模拟
/// Ctrl+V。Flutter Windows Engine 会把这组消息错误地映射成同一个物理键，
/// 导致文本框无法处理粘贴。上游问题：
/// https://github.com/flutter/flutter/issues/143997
class WindowsClipboardHistoryKeyFix {
  WindowsClipboardHistoryKeyFix._();

  static final WindowsClipboardHistoryKeyFix instance =
      WindowsClipboardHistoryKeyFix._();

  final WindowsClipboardHistoryKeyEventNormalizer _normalizer =
      WindowsClipboardHistoryKeyEventNormalizer();

  Timer? _installTimer;
  bool _installed = false;

  void install() {
    if (!Platform.isWindows || _installed || _installTimer != null) return;

    // ServicesBinding 异步同步键盘状态后才注册 onKeyData，因此需要延后包装。
    _installTimer = Timer(const Duration(seconds: 1), () {
      _installTimer = null;
      final callback = PlatformDispatcher.instance.onKeyData;
      if (callback == null || _installed) return;

      PlatformDispatcher.instance.onKeyData = (data) {
        final normalized = _normalizer.normalize(data);
        if (normalized == null) return true;
        return callback(normalized);
      };
      _installed = true;
    });
  }
}

/// 将 Flutter Engine 误报的 Win+V 模拟按键还原为 Ctrl+V。
///
/// 不同 Windows / Flutter 版本会产生两种序列，物理键均为
/// [_invalidPhysicalKey]：
/// - 旧序列：Ctrl↓、空事件、Ctrl↑、Ctrl↓(合成)、Ctrl↑(合成)，V 被误报为 Ctrl。
/// - 新序列：Ctrl↓、Ctrl↑(合成)、V↓、V↑、Ctrl↓(合成)、Ctrl↑(合成)，逻辑键
///   正确，但 Ctrl 在 V 按下前就被释放（Windows 11 26200 + Flutter 3.41 起）。
///
/// 返回 `null` 表示该条无效中间事件应被消费。
class WindowsClipboardHistoryKeyEventNormalizer {
  static const int _invalidPhysicalKey = 0x1600000000;
  static const int _controlLeftPhysicalKey = 0x700e0;
  static const int _controlLeftLogicalKey = 0x200000100;
  static const int _keyVPhysicalKey = 0x70019;
  static const int _keyVLogicalKey = 0x76;

  _ClipboardPasteStage _stage = _ClipboardPasteStage.idle;

  KeyData? normalize(KeyData data) {
    if (data.physical != _invalidPhysicalKey) {
      if (_stage != _ClipboardPasteStage.idle && _isEmptyKeyDown(data)) {
        return null;
      }
      _stage = _ClipboardPasteStage.idle;
      return data;
    }

    final isControl = data.logical == _controlLeftLogicalKey;
    final isKeyV = data.logical == _keyVLogicalKey;
    final isDown = data.type == KeyEventType.down;
    final isUp = data.type == KeyEventType.up;
    final synthesized = data.synthesized;

    switch (_stage) {
      case _ClipboardPasteStage.idle:
        if (isControl && isDown && !synthesized) {
          return _emitControl(
            data,
            KeyEventType.down,
            next: _ClipboardPasteStage.controlDown,
          );
        }
      case _ClipboardPasteStage.controlDown:
        if (isControl && isUp && !synthesized) {
          return _emitKeyV(
            data,
            KeyEventType.down,
            next: _ClipboardPasteStage.legacyKeyVDown,
          );
        }
        if (isControl && isUp && synthesized) {
          return _consume(next: _ClipboardPasteStage.awaitingKeyV);
        }
      case _ClipboardPasteStage.legacyKeyVDown:
        if (isControl && isDown && synthesized) {
          return _emitKeyV(
            data,
            KeyEventType.up,
            next: _ClipboardPasteStage.legacyKeyVUp,
          );
        }
      case _ClipboardPasteStage.legacyKeyVUp:
      case _ClipboardPasteStage.awaitingControlUp:
        if (isControl && isUp && synthesized) {
          return _emitControl(
            data,
            KeyEventType.up,
            next: _ClipboardPasteStage.idle,
          );
        }
      case _ClipboardPasteStage.awaitingKeyV:
        if (isKeyV && isDown) {
          return _emitKeyV(
            data,
            KeyEventType.down,
            next: _ClipboardPasteStage.keyVDown,
          );
        }
      case _ClipboardPasteStage.keyVDown:
        if (isKeyV && isUp) {
          return _emitKeyV(
            data,
            KeyEventType.up,
            next: _ClipboardPasteStage.keyVUp,
          );
        }
      case _ClipboardPasteStage.keyVUp:
        if (isControl && isDown && synthesized) {
          return _consume(next: _ClipboardPasteStage.awaitingControlUp);
        }
    }

    _stage = _ClipboardPasteStage.idle;
    return data;
  }

  bool _isEmptyKeyDown(KeyData data) =>
      data.physical == 0 &&
      data.logical == 0 &&
      data.type == KeyEventType.down &&
      !data.synthesized;

  KeyData? _consume({required _ClipboardPasteStage next}) {
    _stage = next;
    return null;
  }

  KeyData _emitControl(
    KeyData source,
    KeyEventType type, {
    required _ClipboardPasteStage next,
  }) {
    _stage = next;
    return _copyAs(
      source,
      type: type,
      physical: _controlLeftPhysicalKey,
      logical: _controlLeftLogicalKey,
    );
  }

  KeyData _emitKeyV(
    KeyData source,
    KeyEventType type, {
    required _ClipboardPasteStage next,
  }) {
    _stage = next;
    return _copyAs(
      source,
      type: type,
      physical: _keyVPhysicalKey,
      logical: _keyVLogicalKey,
    );
  }

  KeyData _copyAs(
    KeyData source, {
    required KeyEventType type,
    required int physical,
    required int logical,
  }) {
    return KeyData(
      timeStamp: source.timeStamp,
      type: type,
      physical: physical,
      logical: logical,
      character: null,
      synthesized: false,
    );
  }
}

enum _ClipboardPasteStage {
  idle,

  /// 已输出 Ctrl↓，尚未区分新旧序列。
  controlDown,

  /// 旧序列：已输出 V↓。
  legacyKeyVDown,

  /// 旧序列：已输出 V↑。
  legacyKeyVUp,

  /// 新序列：已消费提前到达的 Ctrl↑(合成)。
  awaitingKeyV,

  /// 新序列：已输出 V↓。
  keyVDown,

  /// 新序列：已输出 V↑。
  keyVUp,

  /// 新序列：已消费 Ctrl↓(合成)，等待最终 Ctrl↑。
  awaitingControlUp,
}
