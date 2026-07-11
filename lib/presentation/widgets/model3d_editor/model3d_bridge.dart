import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// 执行 JS 的函数(生产环境为 InAppWebViewController.evaluateJavascript)
typedef JsEvaluator = Future<void> Function(String source);

/// JS 侧主动事件回调(onReady/onModelLoaded/onLoadError/onDirty)
typedef Model3dEventHandler = void Function(
  String type,
  Map<String, dynamic> data,
);

class Model3dBridgeException implements Exception {
  final String message;

  const Model3dBridgeException(this.message);

  @override
  String toString() => 'Model3dBridgeException: $message';
}

/// Dart↔JS 桥:命令带 requestId,JS 以 response 消息配对回复。
///
/// JS 协议见 assets/model3d_editor/editor.js 顶部注释。
class Model3dBridge {
  Model3dBridge({
    required JsEvaluator evalJs,
    this.timeout = const Duration(seconds: 15),
    this.onEvent,
  }) : _evalJs = evalJs;

  final JsEvaluator _evalJs;
  final Duration timeout;
  final Model3dEventHandler? onEvent;

  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _nextRequestId = 0;
  bool _disposed = false;

  /// 接收 addJavaScriptHandler('naiModel3d') 的回调参数
  ///
  /// 字段类型不符合协议时按缺失处理(命令走超时/通用错误),不向外抛异常。
  void handleJsMessage(List<dynamic> args) {
    if (_disposed) return;
    if (args.isEmpty || args.first is! Map) return;
    final message = (args.first as Map).cast<String, dynamic>();
    final type = message['type'] is String ? message['type'] as String : null;
    if (type == 'response') {
      final requestId =
          message['requestId'] is int ? message['requestId'] as int : null;
      final completer = _pending.remove(requestId);
      if (completer == null) return;
      final data =
          ((message['data'] is Map ? message['data'] as Map : null) ??
                  const {})
              .cast<String, dynamic>();
      if (message['ok'] == true) {
        completer.complete(data);
      } else {
        completer.completeError(Model3dBridgeException(
          data['error']?.toString() ?? 'unknown bridge error',
        ));
      }
    } else if (type != null) {
      final data = Map<String, dynamic>.from(message)..remove('type');
      onEvent?.call(type, data);
    }
  }

  Future<Map<String, dynamic>> _send(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) {
    if (_disposed) {
      return Future.error(
        const Model3dBridgeException('bridge disposed'),
      );
    }
    final requestId = ++_nextRequestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    final command = jsonEncode({
      'type': type,
      'requestId': requestId,
      ...payload,
    });
    unawaited(
      _evalJs('window.naiEditor.dispatch(${jsonEncode(command)})')
          .catchError((Object e) {
        _pending.remove(requestId)?.completeError(
              Model3dBridgeException('evaluateJavascript failed: $e'),
            );
      }),
    );

    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(requestId);
      throw TimeoutException('model3d bridge command timed out: $type');
    });
  }

  Future<Map<String, dynamic>> loadModel({
    String? url,
    String? builtin,
    Map<String, dynamic>? sceneState,
  }) {
    return _send('loadModel', {
      if (url != null) 'url': url,
      if (builtin != null) 'builtin': builtin,
      if (sceneState != null) 'sceneState': sceneState,
    });
  }

  Future<void> setMode({required String mode, String? gizmo}) =>
      _send('setMode', {'mode': mode, if (gizmo != null) 'gizmo': gizmo});

  Future<void> resetPose() => _send('resetPose');

  Future<void> undoPose() => _send('undoPose');

  Future<void> setLight({
    required double intensity,
    required double azimuth,
    required double elevation,
  }) {
    return _send('setLight', {
      'intensity': intensity,
      'azimuth': azimuth,
      'elevation': elevation,
    });
  }

  Future<Uint8List> render({required int width, required int height}) async {
    final data = await _send('render', {'width': width, 'height': height});
    final png = data['png'] as String?;
    if (png == null) {
      throw const Model3dBridgeException('render returned no png');
    }
    return base64Decode(png);
  }

  Future<Map<String, dynamic>> serialize() async {
    final data = await _send('serialize');
    return ((data['sceneState'] as Map?) ?? const {}).cast<String, dynamic>();
  }

  void dispose() {
    _disposed = true;
    for (final completer in _pending.values) {
      completer.completeError(
        const Model3dBridgeException('bridge disposed'),
      );
    }
    _pending.clear();
  }
}
