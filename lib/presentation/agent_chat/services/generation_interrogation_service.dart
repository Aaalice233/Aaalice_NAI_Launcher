import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/services/prompt_assistant_api_client.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import '../../prompt_assistant/services/prompt_assistant_service.dart';
import 'generation_tool_results.dart';
import 'generation_workspace_path_resolver.dart';
import 'agent_resource_resolver.dart';

class GenerationInterrogationService {
  GenerationInterrogationService(
    this._ref,
    this._pathResolver, {
    required AgentResourceResolver resourceResolver,
    Uint8List? Function(int index)? readAttachedImage,
  }) : _resourceResolver = resourceResolver,
       _readAttachedImage = readAttachedImage;
  final Ref _ref;
  final GenerationWorkspacePathResolver _pathResolver;
  final AgentResourceResolver _resourceResolver;
  final Uint8List? Function(int index)? _readAttachedImage;

  static bool agentChatSupportsImage({
    required AgentSettings settings,
    required PromptAssistantConfigState promptAssistant,
  }) {
    final reference = settings.chat.modelReference;
    if (!reference.isConfigured) return false;
    final provider = promptAssistant.providers
        .where((item) => item.id == reference.providerId && item.enabled)
        .firstOrNull;
    if (provider == null || !provider.allowImageInput) return false;
    return promptAssistant
        .modelsForProviderTask(
          providerId: reference.providerId,
          taskType: AssistantTaskType.chat,
        )
        .any(
          (model) =>
              !model.isPlaceholder && model.name == reference.model.trim(),
        );
  }

  Future<AgentToolResult> interrogate(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    throwIfAborted(signal);
    final Uint8List bytes;
    try {
      bytes = await _loadImage(args);
      throwIfAborted(signal);
    } on FormatException catch (error) {
      return generationErrorResult(error.message);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Interrogation image loading failed',
        error,
        stackTrace,
        'AgentChat',
      );
      return generationErrorResult(
        signal?.aborted == true
            ? 'Interrogation cancelled.'
            : 'Unable to read the selected image.',
      );
    }
    return _interrogateBytes(bytes, signal);
  }

  Future<AgentToolResult> _interrogateBytes(
    Uint8List bytes,
    AbortSignal? signal,
  ) async {
    // 路由优先级：支持图片输入的对话模型直读 > 专用 reverse 模型（fallback）。
    final config = _ref.read(promptAssistantConfigProvider);
    final agentSettings = _ref.read(agentSettingsProvider).settings;
    final modelReference = agentSettings.chat.modelReference;
    final chatProviderId = modelReference.providerId;
    final chatProvider = config.providers
        .where((p) => p.id == chatProviderId && p.enabled)
        .firstOrNull;
    final chatCapable = agentChatSupportsImage(
      settings: agentSettings,
      promptAssistant: config,
    );
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
            final viaChat = await _collectAgentInterrogation(
              bytes,
              provider: chatProvider!,
              modelReference: modelReference,
              signal: signal,
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

  Future<Uint8List> _loadImage(Map<String, dynamic> args) async {
    final sources = [
      'path',
      'resource_ref',
      'attachment_index',
    ].where((key) => args[key] != null);
    if (sources.length != 1) {
      throw const FormatException(
        'Provide exactly one of path, resource_ref, or attachment_index.',
      );
    }
    Uint8List? bytes;
    if (args['attachment_index'] case final Object index) {
      if (index is! int || index < 1) {
        throw const FormatException(
          'attachment_index must be a positive integer.',
        );
      }
      bytes = _readAttachedImage?.call(index);
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(
          'Image attachment not found in the latest user message.',
        );
      }
    } else if (args['resource_ref'] case final Object rawReference) {
      final reference = _resourceResolver.decode(rawReference);
      await _resourceResolver.validateImageResource(reference);
      final resolved = await _resourceResolver.resolve(reference);
      bytes = resolved?.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(
          'The referenced resource has no available image data.',
        );
      }
    } else {
      final path = args['path'];
      if (path is! String || path.trim().isEmpty) {
        throw const FormatException('path must be a non-empty string.');
      }
      final String resolvedPath;
      try {
        resolvedPath = await _pathResolver.resolveLocalImagePath(path.trim());
      } on Object {
        throw const FormatException('Image path is not permitted.');
      }
      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw const FormatException('Image not found.');
      }
      bytes = await file.readAsBytes();
    }
    if (_imageMimeType(bytes) == 'application/octet-stream') {
      throw const FormatException(
        'Selected data is not a supported PNG, JPEG, or WebP image.',
      );
    }
    return bytes;
  }

  Future<String> _collectAgentInterrogation(
    Uint8List bytes, {
    required ProviderConfig provider,
    required AgentModelReference modelReference,
    AbortSignal? signal,
  }) async {
    final apiClient = PromptAssistantApiClient(
      dio: _ref.read(promptAssistantDioProvider),
    );
    const sessionId = 'agent_interrogate';
    void cancel(String? _) =>
        apiClient.cancelCurrentRequest(sessionId: sessionId);

    signal?.addListener(cancel);
    try {
      final apiKey = await _ref
          .read(promptAssistantConfigProvider.notifier)
          .getProviderApiKey(provider.id);
      final output = StringBuffer();
      await for (final chunk in apiClient.complete(
        request: PromptAssistantRequest(
          sessionId: sessionId,
          provider: provider,
          model: modelReference.model,
          systemPrompt:
              'Reverse-engineer the image as a NovelAI prompt. Strictly '
              'output one single-line English comma-separated prompt. Do '
              'not use Markdown or explanations, and do not invent unseen '
              'character information.',
          userParts: [
            PromptAssistantContentPart.text(
              'Describe the visible subject, character, style, clothing, '
              'action, composition, lighting, and background.',
            ),
            PromptAssistantContentPart.image(
              bytes: bytes,
              mimeType: _imageMimeType(bytes),
            ),
          ],
          apiKey: apiKey,
        ),
      )) {
        throwIfAborted(signal);
        output.write(chunk.delta);
      }
      return output.toString().trim();
    } finally {
      signal?.removeListener(cancel);
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

String _imageMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'application/octet-stream';
}
