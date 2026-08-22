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
/// 返回 `null` 表示该条无效中间事件应被消费。
class WindowsClipboardHistoryKeyEventNormalizer {
  static const int _invalidPhysicalKey = 0x1600000000;
  static const int _controlLeftPhysicalKey = 0x700e0;
  static const int _controlLeftLogicalKey = 0x200000100;
  static const int _keyVPhysicalKey = 0x70019;
  static const int _keyVLogicalKey = 0x76;

  bool _normalizingClipboardPaste = false;

  KeyData? normalize(KeyData data) {
    if (!_normalizingClipboardPaste &&
        data.physical == _invalidPhysicalKey &&
        data.logical == _controlLeftLogicalKey &&
        data.type == KeyEventType.down &&
        !data.synthesized) {
      _normalizingClipboardPaste = true;
      return _copyAs(
        data,
        type: KeyEventType.down,
        physical: _controlLeftPhysicalKey,
        logical: _controlLeftLogicalKey,
      );
    }

    if (_normalizingClipboardPaste &&
        data.physical == 0 &&
        data.logical == 0 &&
        data.type == KeyEventType.down &&
        !data.synthesized) {
      return null;
    }

    if (_normalizingClipboardPaste &&
        data.physical == _invalidPhysicalKey &&
        data.logical == _controlLeftLogicalKey &&
        data.type == KeyEventType.up &&
        !data.synthesized) {
      return _copyAs(
        data,
        type: KeyEventType.down,
        physical: _keyVPhysicalKey,
        logical: _keyVLogicalKey,
      );
    }

    if (_normalizingClipboardPaste &&
        data.physical == _invalidPhysicalKey &&
        data.logical == _controlLeftLogicalKey &&
        data.type == KeyEventType.down &&
        data.synthesized) {
      return _copyAs(
        data,
        type: KeyEventType.up,
        physical: _keyVPhysicalKey,
        logical: _keyVLogicalKey,
      );
    }

    if (_normalizingClipboardPaste &&
        data.physical == _invalidPhysicalKey &&
        data.logical == _controlLeftLogicalKey &&
        data.type == KeyEventType.up &&
        data.synthesized) {
      _normalizingClipboardPaste = false;
      return _copyAs(
        data,
        type: KeyEventType.up,
        physical: _controlLeftPhysicalKey,
        logical: _controlLeftLogicalKey,
      );
    }

    _normalizingClipboardPaste = false;
    return data;
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
