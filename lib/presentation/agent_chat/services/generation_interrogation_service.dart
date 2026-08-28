import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/app_logger.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/services/prompt_assistant_service.dart';
import 'generation_tool_results.dart';
import 'generation_workspace_path_resolver.dart';

class GenerationInterrogationService {
  GenerationInterrogationService(this._ref, this._pathResolver);
  final Ref _ref;
  final GenerationWorkspacePathResolver _pathResolver;
  Future<AgentToolResult> interrogate(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    throwIfAborted(signal);
    final path = (args['path'] as String?)?.trim() ?? '';
    if (path.isEmpty) {
      return generationErrorResult('Parameter "path" is required.');
    }
    String resolvedPath;
    try {
      resolvedPath = await _pathResolver.resolveLocalImagePath(path);
    } on Object {
      return generationErrorResult('Image path is not permitted.');
    }
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return generationErrorResult('Image not found.');
    }
    // 路由优先级：支持图片输入的对话模型直读 > 专用 reverse 模型（fallback）。
    final config = _ref.read(promptAssistantConfigProvider);
    final chatProviderId = config.routing.providerIdFor(AssistantTaskType.chat);
    final chatProvider = config.providers
        .where((p) => p.id == chatProviderId && p.enabled)
        .firstOrNull;
    final chatCapable = chatProvider != null && chatProvider.allowImageInput;
    final reverseProviderId = config.routing.providerIdFor(
      AssistantTaskType.reverse,
    );
    final reverseReady = config.providers.any(
      (p) => p.id == reverseProviderId && p.enabled,
    );
    if (!chatCapable && !reverseReady) {
      return generationErrorResult(
        'No image-capable model available for interrogation. Enable a chat '
        'provider with image input support, or configure a "reverse" task '
        'vision model in Settings > Integrations.',
      );
    }
    try {
      final bytes = await file.readAsBytes();
      throwIfAborted(signal);
      final service = _ref.read(promptAssistantServiceProvider);
      void cancelInterrogation(String? _) {
        unawaited(service.cancelCurrentTask(sessionId: 'agent_interrogate'));
      }

      signal?.addListener(cancelInterrogation);
      // 对话模型支持图片时直接解析；失败或不可用时回退 reverse 路由。
      try {
        if (chatCapable) {
          try {
            final viaChat = await _collectInterrogation(
              service,
              bytes,
              AssistantTaskType.chat,
              signal,
            );
            if (viaChat.isNotEmpty) {
              return generationTextResult(viaChat);
            }
            AppLogger.w(
              'interrogate via chat route returned empty prompt',
              'AgentChat',
            );
          } catch (e) {
            if (signal?.aborted == true) {
              rethrow;
            }
            AppLogger.w('interrogate via chat route failed: $e', 'AgentChat');
            if (!reverseReady) {
              return generationErrorResult('Interrogation failed.');
            }
          }
        }
        final prompt = await _collectInterrogation(
          service,
          bytes,
          AssistantTaskType.reverse,
          signal,
        );
        if (prompt.isEmpty) {
          return generationErrorResult(
            'Interrogation returned an empty prompt. The reverse model may not '
            'support image input.',
          );
        }
        return generationTextResult(prompt);
      } finally {
        signal?.removeListener(cancelInterrogation);
      }
    } catch (e) {
      AppLogger.w('interrogate_image failed: $e', 'AgentChat');
      if (signal?.aborted == true) {
        return generationErrorResult('Interrogation cancelled.');
      }
      return generationErrorResult('Interrogation failed.');
    }
  }

  /// 按指定任务路由反推图片并聚合流式输出为完整提示词。
  Future<String> _collectInterrogation(
    PromptAssistantService service,
    Uint8List bytes,
    AssistantTaskType route,
    AbortSignal? signal,
  ) async {
    final buffer = StringBuffer();
    throwIfAborted(signal);
    await for (final chunk in service.reverseImagePrompt(
      bytes,
      sessionId: 'agent_interrogate',
      taskType: route,
    )) {
      throwIfAborted(signal);
      buffer.write(chunk.delta);
    }
    throwIfAborted(signal);
    return buffer.toString().trim();
  }

  // -------------------------------------------------------------------------
  // generation transaction lifecycle
  // -------------------------------------------------------------------------
}
