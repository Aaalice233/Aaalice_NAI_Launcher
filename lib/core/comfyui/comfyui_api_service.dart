import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';
import 'comfyui_models.dart';
import 'comfyui_url_utils.dart';

String formatComfyUIErrorResponse(Object? responseData, {String? fallback}) {
  if (responseData is String && responseData.trim().isNotEmpty) {
    return responseData.trim();
  }

  if (responseData is Map) {
    final nodeDetails = <String>[];
    final nodeErrors = responseData['node_errors'];
    if (nodeErrors is Map) {
      for (final entry in nodeErrors.entries) {
        final nodeError = entry.value;
        if (nodeError is! Map) continue;
        final nodeType = nodeError['class_type']?.toString();
        final errors = nodeError['errors'];
        if (errors is! List) continue;

        for (final error in errors.whereType<Map>()) {
          final message = error['message']?.toString().trim() ?? '';
          final details = error['details']?.toString().trim() ?? '';
          final description = [
            if (message.isNotEmpty) message,
            if (details.isNotEmpty && details != message) details,
          ].join(': ');
          if (description.isEmpty) continue;
          final nodeLabel = nodeType == null || nodeType.isEmpty
              ? '节点 ${entry.key}'
              : '节点 ${entry.key} ($nodeType)';
          nodeDetails.add('$nodeLabel: $description');
        }
      }
    }
    if (nodeDetails.isNotEmpty) {
      return nodeDetails.join('；');
    }

    final error = responseData['error'];
    if (error is Map) {
      final type = error['type']?.toString().trim() ?? '';
      final message = error['message']?.toString().trim() ?? '';
      final details = error['details']?.toString().trim() ?? '';
      final parts = [
        if (type.isNotEmpty) type,
        if (message.isNotEmpty && message != type) message,
        if (details.isNotEmpty && details != message) details,
      ];
      if (parts.isNotEmpty) return parts.join(': ');
    } else if (error != null && error.toString().trim().isNotEmpty) {
      return error.toString().trim();
    }
  }

  return fallback?.trim().isNotEmpty == true ? fallback!.trim() : '未知错误';
}

/// ComfyUI HTTP API 服务
///
/// 封装 ComfyUI 服务端的 REST 端点：
/// - POST /prompt      提交工作流
/// - POST /upload/image 上传图像
/// - GET  /history      获取历史
/// - GET  /view         下载输出图像
/// - GET  /object_info  查询节点/模型信息
/// - GET  /system_stats 系统状态
class ComfyUIApiService {
  static const String _tag = 'ComfyUI';

  final Dio _dio;
  final String baseUrl;

  ComfyUIApiService({required String baseUrl})
    : this._(normalizeComfyUIBaseUrl(baseUrl));

  ComfyUIApiService._(this.baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 300),
        ),
      );

  /// 测试连接是否可用
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/system_stats');
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.w('Connection test failed: $e', _tag);
      return false;
    }
  }

  /// 获取系统状态
  Future<ComfyUISystemStats> getSystemStats() async {
    try {
      final response = await _dio.get('/system_stats');
      final data = response.data as Map<String, dynamic>;
      final devices = data['devices'] as List?;
      if (devices != null && devices.isNotEmpty) {
        final gpu = devices[0] as Map<String, dynamic>;
        return ComfyUISystemStats(
          cudaDevice: gpu['name'] as String?,
          vramTotal: gpu['vram_total'] as int?,
          vramFree: gpu['vram_free'] as int?,
        );
      }
      return const ComfyUISystemStats();
    } catch (e) {
      AppLogger.w('Failed to get system stats: $e', _tag);
      rethrow;
    }
  }

  /// 提交工作流执行
  ///
  /// [workflow] 是 workflow_api.json 格式的节点字典
  /// [clientId] 用于 WebSocket 进度追踪
  Future<ComfyUIPromptResult> queuePrompt({
    required Map<String, dynamic> workflow,
    required String clientId,
  }) async {
    try {
      final response = await _dio.post(
        '/prompt',
        data: {'prompt': workflow, 'client_id': clientId},
      );
      final data = response.data as Map<String, dynamic>;
      return ComfyUIPromptResult(
        promptId: data['prompt_id'] as String,
        number: data['number'] as int?,
      );
    } on DioException catch (e) {
      final detail = _extractErrorDetail(e);
      AppLogger.e('Queue prompt failed: $detail', _tag);
      throw ComfyUIApiException('提交工作流失败: $detail');
    }
  }

  /// 上传图像到 ComfyUI input 目录
  ///
  /// 返回上传后的文件名（ComfyUI 可能重命名）
  Future<String> uploadImage({
    required Uint8List imageBytes,
    required String filename,
    bool overwrite = true,
    String type = 'input',
    String? subfolder,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageBytes, filename: filename),
        'overwrite': overwrite.toString(),
        'type': type,
        if (subfolder != null) 'subfolder': subfolder,
      });
      final response = await _dio.post('/upload/image', data: formData);
      final data = response.data as Map<String, dynamic>;
      return data['name'] as String;
    } on DioException catch (e) {
      AppLogger.e('Upload image failed: ${e.message}', _tag);
      throw ComfyUIApiException('上传图像失败: ${_extractErrorDetail(e)}');
    }
  }

  /// 获取任务历史
  Future<Map<String, dynamic>?> getHistory(String promptId) async {
    try {
      final response = await _dio.get('/history/$promptId');
      final data = response.data as Map<String, dynamic>;
      return data[promptId] as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.w('Failed to get history for $promptId: $e', _tag);
      return null;
    }
  }

  /// 下载输出图像
  Future<Uint8List> viewImage({
    required String filename,
    String type = 'output',
    String? subfolder,
  }) async {
    try {
      final response = await _dio.get(
        '/view',
        queryParameters: {
          'filename': filename,
          'type': type,
          if (subfolder != null) 'subfolder': subfolder,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data as List<int>);
    } on DioException catch (e) {
      AppLogger.e('View image failed: ${e.message}', _tag);
      throw ComfyUIApiException('获取图像失败: ${_extractErrorDetail(e)}');
    }
  }

  /// 从历史记录中提取并下载输出图像
  ///
  /// [allowedNodeIds] 用于限制只回收声明过的输出节点，避免把输入预览误当结果。
  Future<List<Uint8List>> getOutputImages(
    String promptId, {
    Set<String>? allowedNodeIds,
  }) async {
    final history = await getHistory(promptId);
    if (history == null) {
      throw ComfyUIApiException('未找到任务历史: $promptId');
    }

    final refs = extractHistoryImageRefs(
      history,
      allowedNodeIds: allowedNodeIds,
    );
    final images = <Uint8List>[];
    for (final ref in refs) {
      final bytes = await viewImage(
        filename: ref.filename,
        type: ref.type,
        subfolder: (ref.subfolder?.isEmpty ?? true) ? null : ref.subfolder,
      );
      images.add(bytes);
    }
    return images;
  }

  /// 查询节点类型信息（可用于获取模型列表等）
  ///
  /// [nodeClass] 为 null 时返回全部节点信息
  Future<Map<String, dynamic>> getObjectInfo([String? nodeClass]) async {
    try {
      final path = nodeClass != null
          ? '/object_info/$nodeClass'
          : '/object_info';
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      AppLogger.w('Failed to get object info: $e', _tag);
      rethrow;
    }
  }

  /// 中断当前执行
  Future<void> interrupt() async {
    try {
      await _dio.post('/interrupt');
    } catch (e) {
      AppLogger.w('Interrupt failed: $e', _tag);
    }
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }

  String _extractErrorDetail(DioException e) {
    if (e.response?.data != null) {
      try {
        return formatComfyUIErrorResponse(
          e.response!.data,
          fallback: e.message,
        );
      } catch (e) {
        AppLogger.d('Failed to parse ComfyUI error response: $e', _tag);
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return '无法连接到 ComfyUI 服务器 ($baseUrl)';
    }
    return e.message ?? '未知错误';
  }
}

class ComfyUIHistoryImageRef {
  const ComfyUIHistoryImageRef({
    required this.nodeId,
    required this.filename,
    required this.type,
    this.subfolder,
  });

  final String nodeId;
  final String filename;
  final String type;
  final String? subfolder;
}

List<ComfyUIHistoryImageRef> extractHistoryImageRefs(
  Map<String, dynamic> history, {
  Set<String>? allowedNodeIds,
}) {
  final outputs = history['outputs'] as Map<String, dynamic>?;
  if (outputs == null || outputs.isEmpty) {
    throw const ComfyUIApiException('任务无输出');
  }

  final refs = <ComfyUIHistoryImageRef>[];
  for (final entry in outputs.entries) {
    final nodeId = entry.key;
    if (allowedNodeIds != null && !allowedNodeIds.contains(nodeId)) {
      continue;
    }

    final nodeData = entry.value as Map<String, dynamic>;
    final imageList = nodeData['images'] as List?;
    if (imageList == null) continue;

    for (final imgInfo in imageList) {
      final info = imgInfo as Map<String, dynamic>;
      refs.add(
        ComfyUIHistoryImageRef(
          nodeId: nodeId,
          filename: info['filename'] as String,
          type: info['type'] as String? ?? 'output',
          subfolder: info['subfolder'] as String?,
        ),
      );
    }
  }

  if (refs.isEmpty && allowedNodeIds != null && allowedNodeIds.isNotEmpty) {
    final joined = allowedNodeIds.toList()..sort();
    throw ComfyUIApiException('指定输出节点无图像输出: ${joined.join(", ")}');
  }
  if (refs.isEmpty) {
    throw const ComfyUIApiException('任务无图像输出');
  }
  return refs;
}

class ComfyUIApiException implements Exception {
  final String message;
  const ComfyUIApiException(this.message);
  @override
  String toString() => message;
}
