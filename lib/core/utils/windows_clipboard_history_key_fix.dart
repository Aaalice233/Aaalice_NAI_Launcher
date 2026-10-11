import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'app_logger.dart';

/// 修正 Windows 剪贴板历史粘贴生成的异常按键序列。
///
/// Win+V 选中条目后，系统用扫描码为 0 的消息模拟 Ctrl+V。Flutter Windows
/// Engine 把 Ctrl 与 V 映射到同一个物理键，并在 V 按下前合成 Ctrl 抬起，
/// 框架因此收不到 Ctrl+V。上游问题：
/// https://github.com/flutter/flutter/issues/143997
class WindowsClipboardHistoryKeyFix {
  WindowsClipboardHistoryKeyFix._();

  static final WindowsClipboardHistoryKeyFix instance =
      WindowsClipboardHistoryKeyFix._();

  static const String _logTag = 'WindowsClipboardHistoryKeyFix';
  static const Duration _installPollInterval = Duration(milliseconds: 50);
  static const Duration _installTimeout = Duration(seconds: 30);
  // 实测整段序列约 130ms，超过 1 秒仍未走完视为中断。
  static const Duration _sequenceTimeout = Duration(seconds: 1);

  final WindowsClipboardHistoryKeyEventNormalizer _normalizer =
      WindowsClipboardHistoryKeyEventNormalizer(
        isPhysicalKeyPressed: (physical) => HardwareKeyboard
            .instance
            .physicalKeysPressed
            .contains(PhysicalKeyboardKey(physical)),
      );

  KeyDataCallback? _frameworkCallback;
  Timer? _installTimer;
  Timer? _sequenceWatchdog;

  void install() {
    if (!Platform.isWindows ||
        _frameworkCallback != null ||
        _installTimer != null) {
      return;
    }

    // ServicesBinding 在 syncKeyboardState 异步完成后才注册 onKeyData。
    final elapsed = Stopwatch()..start();
    _installTimer = Timer.periodic(_installPollInterval, (timer) {
      final callback = PlatformDispatcher.instance.onKeyData;
      if (callback != null) {
        timer.cancel();
        _installTimer = null;
        _frameworkCallback = callback;
        PlatformDispatcher.instance.onKeyData = _handleKeyData;
        return;
      }
      if (elapsed.elapsed >= _installTimeout) {
        timer.cancel();
        _installTimer = null;
        AppLogger.w(
          'onKeyData not registered within ${_installTimeout.inSeconds}s, '
          'clipboard history paste fix not installed',
          _logTag,
        );
      }
    });
  }

  bool _handleKeyData(KeyData data) {
    final handled = _dispatch(_normalizer.normalize(data));
    _rearmSequenceWatchdog();
    return handled;
  }

  bool _dispatch(List<KeyData> events) {
    final callback = _frameworkCallback!;
    var handled = false;
    for (final event in events) {
      handled = callback(event) || handled;
    }
    return handled;
  }

  void _rearmSequenceWatchdog() {
    _sequenceWatchdog?.cancel();
    _sequenceWatchdog = null;
    if (!_normalizer.isNormalizing) return;

    _sequenceWatchdog = Timer(_sequenceTimeout, () {
      _sequenceWatchdog = null;
      _dispatch(_normalizer.abandon());
    });
  }
}

/// 将 Win+V 模拟的按键序列还原为物理键正确、顺序正确的 Ctrl+V。
///
/// 改写后的事件保留原事件的 synthesized 标记：KeyEventManager 据此决定
/// 立即派发还是等待对应的 RAW 消息，改动它会改变派发时机。
class WindowsClipboardHistoryKeyEventNormalizer {
  WindowsClipboardHistoryKeyEventNormalizer({
    required bool Function(int physical) isPhysicalKeyPressed,
  }) : _isPhysicalKeyPressed = isPhysicalKeyPressed;

  // 扫描码为 0 时 Engine 生成的 Windows plane 物理键。
  static const int _injectedPhysicalKey = 0x1600000000;
  static const int _controlLeftLogicalKey = 0x200000100;
  static const int _keyVLogicalKey = 0x76;

  // 实测于 Flutter 3.47.5 / Windows 11：两次合成的 Ctrl 事件都源于 Ctrl 与 V
  // 共用同一物理键，需吞掉；最后一次合成的 Ctrl 抬起才是真实释放。
  static const List<_SequenceStep> _sequence = [
    _SequenceStep(
      _controlLeftLogicalKey,
      KeyEventType.down,
      synthesized: false,
      action: _StepAction.pressControl,
    ),
    _SequenceStep(
      _controlLeftLogicalKey,
      KeyEventType.up,
      synthesized: true,
      action: _StepAction.swallow,
    ),
    _SequenceStep(
      _keyVLogicalKey,
      KeyEventType.down,
      synthesized: false,
      action: _StepAction.pressKeyV,
    ),
    _SequenceStep(
      _keyVLogicalKey,
      KeyEventType.up,
      synthesized: false,
      action: _StepAction.releaseKeyV,
    ),
    _SequenceStep(
      _controlLeftLogicalKey,
      KeyEventType.down,
      synthesized: true,
      action: _StepAction.swallow,
    ),
    _SequenceStep(
      _controlLeftLogicalKey,
      KeyEventType.up,
      synthesized: true,
      action: _StepAction.releaseControl,
    ),
  ];

  final bool Function(int physical) _isPhysicalKeyPressed;
  final _InjectedKey _control = _InjectedKey(
    physical: 0x700e0,
    logical: _controlLeftLogicalKey,
  );
  final _InjectedKey _keyV = _InjectedKey(
    physical: 0x70019,
    logical: _keyVLogicalKey,
  );

  int _position = 0;
  Duration _lastTimeStamp = Duration.zero;

  bool get isNormalizing => _position != 0;

  List<KeyData> normalize(KeyData data) {
    // 全零事件是 Engine 推断传输模式的探针，吞掉会让输入框无法编辑。
    if (data.physical == 0 && data.logical == 0) return [data];

    var released = const <KeyData>[];
    if (!_sequence[_position].matches(data)) {
      released = abandon();
      if (!_sequence[_position].matches(data)) return [...released, data];
    }

    _lastTimeStamp = data.timeStamp;
    final step = _sequence[_position];
    _position = (_position + 1) % _sequence.length;
    return [...released, ..._apply(step.action, data)];
  }

  /// 抬起已注入的键并回到初始状态，用于序列中断或超时。
  List<KeyData> abandon() {
    _position = 0;
    return [
      _keyV.release(_lastTimeStamp, synthesized: true),
      _control.release(_lastTimeStamp, synthesized: true),
    ].nonNulls.toList();
  }

  List<KeyData> _apply(_StepAction action, KeyData source) {
    final event = switch (action) {
      _StepAction.swallow => null,
      _StepAction.pressControl => _control.press(source, _isPhysicalKeyPressed),
      _StepAction.pressKeyV => _keyV.press(source, _isPhysicalKeyPressed),
      _StepAction.releaseKeyV => _keyV.release(
        source.timeStamp,
        synthesized: source.synthesized,
      ),
      _StepAction.releaseControl => _control.release(
        source.timeStamp,
        synthesized: source.synthesized,
      ),
    };
    return event == null ? const [] : [event];
  }
}

enum _StepAction {
  pressControl,
  swallow,
  pressKeyV,
  releaseKeyV,
  releaseControl,
}

class _SequenceStep {
  const _SequenceStep(
    this.logical,
    this.type, {
    required this.synthesized,
    required this.action,
  });

  final int logical;
  final KeyEventType type;
  final bool synthesized;
  final _StepAction action;

  bool matches(KeyData data) {
    return data.physical ==
            WindowsClipboardHistoryKeyEventNormalizer._injectedPhysicalKey &&
        data.logical == logical &&
        data.type == type &&
        data.synthesized == synthesized;
  }
}

/// 序列中由本修正注入的键；用户已真实按住时不重复注入，也不代为抬起。
class _InjectedKey {
  _InjectedKey({required this.physical, required this.logical});

  final int physical;
  final int logical;
  bool _held = false;

  KeyData? press(
    KeyData source,
    bool Function(int physical) isPhysicalKeyPressed,
  ) {
    if (_held || isPhysicalKeyPressed(physical)) return null;
    _held = true;
    return _event(
      KeyEventType.down,
      source.timeStamp,
      synthesized: source.synthesized,
      deviceType: source.deviceType,
    );
  }

  KeyData? release(Duration timeStamp, {required bool synthesized}) {
    if (!_held) return null;
    _held = false;
    return _event(KeyEventType.up, timeStamp, synthesized: synthesized);
  }

  KeyData _event(
    KeyEventType type,
    Duration timeStamp, {
    required bool synthesized,
    KeyEventDeviceType deviceType = KeyEventDeviceType.keyboard,
  }) {
    return KeyData(
      timeStamp: timeStamp,
      type: type,
      physical: physical,
      logical: logical,
      character: null,
      synthesized: synthesized,
      deviceType: deviceType,
    );
  }
}
