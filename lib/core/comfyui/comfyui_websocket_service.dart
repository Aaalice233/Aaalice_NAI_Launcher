import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/app_logger.dart';
import 'comfyui_models.dart';
import 'comfyui_url_utils.dart';

/// ComfyUI WebSocket 服务
///
/// 连接 ComfyUI 的 /ws 端点，接收实时进度事件。
/// 同时处理 SaveImageWebsocket 节点的二进制图像帧。
class ComfyUIWebSocketService {
  static const String _tag = 'ComfyUI-WS';

  final String baseUrl;
  final String clientId;
  final ComfyUIBinaryFrameDecoder _binaryFrameDecoder;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;

  final _progressController = StreamController<ComfyUIProgress>.broadcast();
  final _imageController = StreamController<ComfyUIImageFrame>.broadcast();

  /// 进度事件流
  Stream<ComfyUIProgress> get progressStream => _progressController.stream;

  /// 从 SaveImageWebsocket 接收的图像帧流（含预览/最终标记）
  Stream<ComfyUIImageFrame> get imageStream => _imageController.stream;

  /// 当前追踪的 promptId
  String? _trackingPromptId;

  ComfyUIWebSocketService({
    required String baseUrl,
    required this.clientId,
    ComfyUIBinaryFrameDecoder? binaryFrameDecoder,
  }) : baseUrl = normalizeComfyUIBaseUrl(baseUrl),
       _binaryFrameDecoder = binaryFrameDecoder ?? ComfyUIBinaryFrameDecoder();

  /// 连接到 ComfyUI WebSocket
  Future<void> connect() async {
    if (_disposed) return;
    await disconnect();

    final uri = buildComfyUIWebSocketUri(baseUrl: baseUrl, clientId: clientId);

    AppLogger.i('Connecting to $uri', _tag);

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      AppLogger.i('WebSocket connected', _tag);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          AppLogger.e('WebSocket error: $error', _tag);
        },
        onDone: () {
          AppLogger.i('WebSocket closed', _tag);
        },
      );
    } catch (e) {
      AppLogger.e('WebSocket connection failed: $e', _tag);
      rethrow;
    }
  }

  /// 开始追踪指定 prompt 的进度
  void trackPrompt(String promptId) {
    _trackingPromptId = promptId;
  }

  /// 断开连接
  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _trackingPromptId = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _progressController.close();
    _imageController.close();
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      _handleJsonMessage(message);
    } else if (message is Uint8List) {
      _handleBinaryMessage(message);
    } else if (message is List<int>) {
      _handleBinaryMessage(Uint8List.fromList(message));
    }
  }

  void _handleJsonMessage(String raw) {
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'status':
          break;

        case 'execution_start':
          final execData = data['data'] as Map<String, dynamic>?;
          final promptId = execData?['prompt_id'] as String?;
          if (promptId != null && promptId == _trackingPromptId) {
            _progressController.add(
              ComfyUIProgress(
                promptId: promptId,
                status: ComfyUITaskStatus.running,
              ),
            );
          }
          break;

        case 'executing':
          final execData = data['data'] as Map<String, dynamic>?;
          final nodeId = execData?['node'] as String?;
          final promptId = execData?['prompt_id'] as String?;
          if (promptId != null && promptId == _trackingPromptId) {
            if (nodeId == null) {
              _progressController.add(
                ComfyUIProgress(
                  promptId: promptId,
                  status: ComfyUITaskStatus.completed,
                ),
              );
            } else {
              _progressController.add(
                ComfyUIProgress(
                  promptId: promptId,
                  status: ComfyUITaskStatus.running,
                  currentNodeId: nodeId,
                ),
              );
            }
          }
          break;

        case 'progress':
          final progData = data['data'] as Map<String, dynamic>?;
          if (progData != null) {
            final promptId = progData['prompt_id'] as String?;
            if (promptId == _trackingPromptId || _trackingPromptId == null) {
              _progressController.add(
                ComfyUIProgress(
                  promptId: promptId ?? '',
                  status: ComfyUITaskStatus.running,
                  currentStep: progData['value'] as int? ?? 0,
                  totalSteps: progData['max'] as int? ?? 0,
                ),
              );
            }
          }
          break;

        case 'execution_cached':
          break;

        case 'execution_error':
          final errData = data['data'] as Map<String, dynamic>?;
          final promptId = errData?['prompt_id'] as String?;
          if (promptId != null && promptId == _trackingPromptId) {
            _progressController.add(
              ComfyUIProgress(
                promptId: promptId,
                status: ComfyUITaskStatus.failed,
                errorMessage:
                    errData?['exception_message'] as String? ??
                    errData?['exception_type'] as String? ??
                    '执行出错',
              ),
            );
          }
          break;
      }
    } catch (e) {
      AppLogger.w('Failed to parse WS message: $e', _tag);
    }
  }

  /// 处理 SaveImageWebsocket 的二进制帧
  ///
  /// ComfyUI WebSocket 二进制帧格式（大端序，与 Python struct.pack(">I",..) 一致）:
  ///   byte[0..3] = event type (uint32 BE)
  ///     1 = preview image (中间步骤预览)
  ///     2 = 最终输出图像 (SaveImageWebsocket)
  ///   byte[4..7] = image format (uint32 BE)，1=JPEG, 2=PNG
  ///   byte[8..] = image data
  void _handleBinaryMessage(Uint8List data) {
    final frame = _binaryFrameDecoder.decode(data);
    if (frame == null) return;

    _imageController.add(frame);

    AppLogger.d(
      'Received ${frame.isPreview ? "preview" : "final"} image: ${frame.data.length} bytes',
      _tag,
    );
  }
}

class ComfyUIBinaryFrameDecoder {
  ComfyUIBinaryFrameDecoder({
    this.previewMinInterval = const Duration(milliseconds: 250),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration previewMinInterval;
  final DateTime Function() _now;

  DateTime? _lastPreviewEmittedAt;

  ComfyUIImageFrame? decode(Uint8List data) {
    if (data.length < 8) return null;

    final bd = ByteData.sublistView(data, 0, 8);
    final eventType = bd.getUint32(0, Endian.big);
    if (eventType != 1 && eventType != 2) {
      return null;
    }

    final imageData = Uint8List.sublistView(data, 8);
    if (imageData.isEmpty) return null;

    final isPreview = eventType == 1;
    if (isPreview && !_shouldEmitPreview()) {
      return null;
    }

    return ComfyUIImageFrame(data: imageData, isPreview: isPreview);
  }

  bool _shouldEmitPreview() {
    if (previewMinInterval <= Duration.zero) {
      return true;
    }

    final current = _now();
    final last = _lastPreviewEmittedAt;
    if (last != null && current.difference(last) < previewMinInterval) {
      return false;
    }

    _lastPreviewEmittedAt = current;
    return true;
  }
}

/// ComfyUI WebSocket 二进制图像帧
class ComfyUIImageFrame {
  final Uint8List data;
  final bool isPreview;

  const ComfyUIImageFrame({required this.data, this.isPreview = false});
}
