import 'dart:async';

import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import '../utils/log_url_redaction.dart';
import 'comfyui_api_service.dart';
import 'comfyui_models.dart';
import 'comfyui_url_utils.dart';
import 'comfyui_websocket_service.dart';

/// ComfyUI 连接管理器
///
/// 管理与 ComfyUI 服务器的连接生命周期，包括：
/// - HTTP API 服务实例
/// - WebSocket 进度服务实例
/// - 连接状态追踪
/// - 心跳检测
class ComfyUIConnectionManager {
  static const String _tag = 'ComfyUI-Conn';

  String _serverUrl;
  final String clientId;

  ComfyUIApiService? _apiService;
  ComfyUIWebSocketService? _wsService;
  Timer? _heartbeatTimer;

  final _statusController =
      StreamController<ComfyUIConnectionStatus>.broadcast();

  ComfyUIConnectionStatus _status = ComfyUIConnectionStatus.disconnected;

  ComfyUIConnectionStatus get status => _status;
  Stream<ComfyUIConnectionStatus> get statusStream => _statusController.stream;
  String get serverUrl => _serverUrl;

  ComfyUIApiService? get api => _apiService;
  ComfyUIWebSocketService? get ws => _wsService;

  ComfyUIConnectionManager({
    String serverUrl = 'http://127.0.0.1:8188',
  })  : _serverUrl = normalizeComfyUIBaseUrl(serverUrl),
        clientId = const Uuid().v4();

  /// 更新服务器地址（需要重新连接）
  void updateServerUrl(String url) {
    final normalizedUrl = normalizeComfyUIBaseUrl(url);
    if (normalizedUrl == _serverUrl) return;
    _serverUrl = normalizedUrl;
    if (_status == ComfyUIConnectionStatus.connected) {
      disconnect();
    }
  }

  /// 连接到 ComfyUI
  Future<bool> connect() async {
    if (_status == ComfyUIConnectionStatus.connecting) return false;

    _setStatus(ComfyUIConnectionStatus.connecting);

    try {
      _apiService?.dispose();
      _apiService = ComfyUIApiService(baseUrl: _serverUrl);

      final ok = await _apiService!.testConnection();
      if (!ok) {
        _setStatus(ComfyUIConnectionStatus.error);
        return false;
      }

      _wsService?.dispose();
      _wsService = ComfyUIWebSocketService(
        baseUrl: _serverUrl,
        clientId: clientId,
      );
      await _wsService!.connect();

      _startHeartbeat();
      _setStatus(ComfyUIConnectionStatus.connected);
      AppLogger.i(
        'Connected to ComfyUI at ${redactUrlsInLogText(_serverUrl)}',
        _tag,
      );
      return true;
    } catch (e) {
      AppLogger.e('Failed to connect: $e', _tag);
      _setStatus(ComfyUIConnectionStatus.error);
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _wsService?.dispose();
    _wsService = null;
    _apiService?.dispose();
    _apiService = null;
    _setStatus(ComfyUIConnectionStatus.disconnected);
    AppLogger.i('Disconnected from ComfyUI', _tag);
  }

  /// 释放所有资源
  void dispose() {
    disconnect();
    _statusController.close();
  }

  void _setStatus(ComfyUIConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_apiService == null) return;
        try {
          final ok = await _apiService!.testConnection();
          if (!ok && _status == ComfyUIConnectionStatus.connected) {
            _setStatus(ComfyUIConnectionStatus.error);
          }
        } catch (_) {
          if (_status == ComfyUIConnectionStatus.connected) {
            _setStatus(ComfyUIConnectionStatus.error);
          }
        }
      },
    );
  }
}
