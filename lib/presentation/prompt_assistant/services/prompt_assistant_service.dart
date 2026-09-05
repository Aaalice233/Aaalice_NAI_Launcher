import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/autocomplete/local_first_prompt_translation.dart';
import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/prompt_edit_document.dart';
import '../../../core/utils/app_logger.dart';
import '../../providers/proxy_settings_provider.dart';
import '../models/prompt_assistant_models.dart';
import '../providers/prompt_assistant_config_provider.dart';
import 'provider_adapters/prompt_assistant_adapter.dart';
import 'prompt_assistant_api_client.dart';

final promptAssistantDioProvider = Provider<Dio>((ref) {
  // 监听代理设置变化触发重建：默认适配器在创建 HttpClient 时才读取
  // HttpOverrides.global，代理变更后需要新实例才能走新代理。
  ref.watch(currentProxyAddressProvider);
  // 使用独立 Dio，避免第三方服务的 401 触发全局登录态刷新/登出逻辑。
  // 始终使用默认 HTTP/1.1 适配器（内部使用 dart:io.HttpClient，
  // 自动遵循 HttpOverrides.global），保证有代理时流量走应用代理。
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
});

final promptAssistantServiceProvider = Provider<PromptAssistantService>((ref) {
  final dio = ref.watch(promptAssistantDioProvider);
  return PromptAssistantService(
    ref: ref,
    apiClient: PromptAssistantApiClient(dio: dio),
    localFirstTranslation: LocalFirstPromptTranslationPipeline(
      ref.watch(tagTranslationLookupProvider),
    ),
  );
});

class TagTranslationBatchResult {
  const TagTranslationBatchResult({
    required this.translations,
    required this.routeFingerprint,
  });

  final Map<String, String> translations;
  final String routeFingerprint;
}

class PromptAssistantService {
  PromptAssistantService({
    required Ref ref,
    required PromptAssistantApiClient apiClient,
    LocalFirstPromptTranslationPipeline? localFirstTranslation,
  }) : _ref = ref,
       _apiClient = apiClient,
       _localFirstTranslation = localFirstTranslation;

  final Ref _ref;
  final PromptAssistantApiClient _apiClient;
  final LocalFirstPromptTranslationPipeline? _localFirstTranslation;

  Future<void> cancelCurrentTask({String? sessionId}) async {
    _apiClient.cancelCurrentRequest(sessionId: sessionId);
  }

  Future<List<String>> fetchAvailableModels(String providerId) async {
    final config = _ref.read(promptAssistantConfigProvider);
    final provider = config.providers.firstWhere(
      (p) => p.id == providerId,
      orElse: () => throw StateError('Provider not found: $providerId'),
    );
    final apiKey = await _ref
        .read(promptAssistantConfigProvider.notifier)
        .getProviderApiKey(provider.id);
    return _apiClient.fetchModels(provider: provider, apiKey: apiKey);
  }

  Stream<StreamingChunk> optimizePrompt(
    String input, {
    required String sessionId,
  }) async* {
    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.llm,
      userContent: input,
      userInstruction:
          'Optimize this image-generation prompt. Preserve the original intent, enhance details, and output a single-line result.',
    );
  }

  Stream<StreamingChunk> translatePrompt(
    String input, {
    required String sessionId,
    String? targetLanguage,
  }) async* {
    final localFirst = await _localFirstTranslation?.translate(
      input,
      targetLanguage: targetLanguage,
      translateMissing: (tags) async =>
          (await translateTags(tags, sessionId: sessionId)).translations,
    );
    if (localFirst != null) {
      yield StreamingChunk(delta: localFirst.text);
      yield const StreamingChunk(delta: '', done: true);
      return;
    }

    final instruction = targetLanguage == null || targetLanguage.isEmpty
        ? 'Automatically detect the source language and translate between Chinese and English. Return only the translation.'
        : 'Translate the text into $targetLanguage. Return only the translation.';
    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.translate,
      userContent: input,
      userInstruction: instruction,
    );
  }

  static const int tagTranslationPromptVersion = 1;

  /// Fills tag captions without replacing the editable prompt with Chinese.
  Stream<StreamingChunk> translateTagLabels(
    String input, {
    required String sessionId,
  }) async* {
    final lookup = _ref.read(tagTranslationLookupProvider);
    final tags = PromptEditDocument.parse(input)
        .expand((span) => span.leaves)
        .map((span) => TagTranslationLookup.normalizeTag(span.label))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final local = await lookup.translateBatch(tags);
    final missing = tags.where((tag) => !local.containsKey(tag)).toList();
    for (var offset = 0; offset < missing.length; offset += 8) {
      final batch = missing.skip(offset).take(8).toList();
      final result = await _translateTagBatch(
        batch,
        sessionId: sessionId,
        naturalLanguage: true,
      );
      lookup.addTranslations(result.translations);
      // Yield between batches so cancellation stops further requests.
      yield const StreamingChunk(delta: '');
    }
    yield const StreamingChunk(delta: '', done: true);
  }

  Future<TagTranslationBatchResult> translateTags(
    List<String> canonicalTags, {
    required String sessionId,
  }) async {
    final tags = canonicalTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => RegExp(r'^[a-z0-9_():.!+\-]+$').hasMatch(tag))
        .toSet()
        .take(8)
        .toList(growable: false);
    if (tags.isEmpty) {
      return const TagTranslationBatchResult(
        translations: {},
        routeFingerprint: '',
      );
    }

    return _translateTagBatch(tags, sessionId: sessionId);
  }

  Future<TagTranslationBatchResult> _translateTagBatch(
    List<String> tags, {
    required String sessionId,
    bool naturalLanguage = false,
  }) async {
    final execution = await _resolveTaskExecution(AssistantTaskType.translate);
    final systemPrompt =
        '''
${naturalLanguage ? 'Translate image-generation tags and natural-language descriptions into Simplified Chinese. Underscores may represent spaces. Preserve the complete meaning of each description.' : 'You translate Danbooru image-generation tags into concise Simplified Chinese labels.'}
Return exactly one JSON object. Every key must be copied verbatim from the input array and every value must be a non-empty Simplified Chinese string.
Do not add keys, Markdown, comments, explanations, or code fences.
Example JSON: {"blue_eyes":"蓝眼睛"}
Prompt version: $tagTranslationPromptVersion
'''
            .trim();
    final output = StringBuffer();
    await for (final chunk in _apiClient.complete(
      request: PromptAssistantRequest(
        sessionId: sessionId,
        responseTimeout: Duration(
          seconds: _ref
              .read(promptAssistantConfigProvider)
              .responseTimeoutSeconds,
        ),
        provider: execution.provider,
        model: execution.model.name,
        systemPrompt: systemPrompt,
        userParts: [PromptAssistantContentPart.text(jsonEncode(tags))],
        apiKey: execution.apiKey,
        responseFormat: PromptAssistantResponseFormat.jsonObject,
        maxOutputTokens: naturalLanguage ? 4096 : 512,
        reasoningMode: PromptAssistantReasoningMode.disabled,
      ),
    )) {
      output.write(chunk.delta);
    }

    final translations = validateTagTranslationResponse(
      output.toString(),
      tags,
      allowLongText: naturalLanguage,
    );
    return TagTranslationBatchResult(
      translations: translations,
      routeFingerprint:
          '${execution.provider.id}/${execution.model.name}/${execution.provider.protocol.name}',
    );
  }

  static Map<String, String> validateTagTranslationResponse(
    String raw,
    List<String> canonicalTags, {
    bool allowLongText = false,
  }) {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Tag translation response must be a JSON object',
      );
    }
    final allowed = canonicalTags.toSet();
    final translations = <String, String>{};
    for (final entry in decoded.entries) {
      if (!allowed.contains(entry.key) || entry.value is! String) {
        throw const FormatException(
          'Tag translation response contains an invalid entry',
        );
      }
      final value = (entry.value as String).trim();
      if (value.isEmpty ||
          (!allowLongText && value.length > 64) ||
          value.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('Tag translation text is invalid');
      }
      translations[entry.key] = value;
    }
    if (translations.length != canonicalTags.length) {
      throw const FormatException('Tag translation response is incomplete');
    }
    return translations;
  }

  String translateRouteFingerprint() {
    final config = _ref.read(promptAssistantConfigProvider);
    final providerId = config.routing.providerIdFor(
      AssistantTaskType.translate,
    );
    final model = config.routing.modelFor(AssistantTaskType.translate).trim();
    final provider = config.providers.cast<ProviderConfig?>().firstWhere(
      (value) => value?.id == providerId && value?.enabled == true,
      orElse: () => null,
    );
    if (provider == null || model.isEmpty) return '';
    return '${provider.id}/$model/${provider.protocol.name}/${provider.baseUrl}';
  }

  String translateRouteLabel() {
    final config = _ref.read(promptAssistantConfigProvider);
    final providerId = config.routing.providerIdFor(
      AssistantTaskType.translate,
    );
    final model = config.routing.modelFor(AssistantTaskType.translate);
    final provider = config.providers.cast<ProviderConfig?>().firstWhere(
      (value) => value?.id == providerId && value?.enabled == true,
      orElse: () => null,
    );
    if (provider == null || model.trim().isEmpty) return '';
    return '${provider.name} / $model';
  }

  /// 反推图片提示词。
  ///
  /// [taskType] 决定走哪条任务路由：默认 [AssistantTaskType.reverse]
  /// （专用 VLM）；传 [AssistantTaskType.chat] 时复用对话模型路由，
  /// 供对话模型支持图片输入时直接解析。
  Stream<StreamingChunk> reverseImagePrompt(
    Uint8List imageBytes, {
    required String sessionId,
    String? taggerPrompt,
    AssistantTaskType taskType = AssistantTaskType.reverse,
  }) async* {
    final text = StringBuffer(
      'Reverse prompt this image and output English comma-separated prompts that can be used directly in NovelAI.',
    );
    final trimmedTags = taggerPrompt?.trim();
    if (trimmedTags != null && trimmedTags.isNotEmpty) {
      text
        ..write(
          '\n\nLocal ONNX tagger preliminary results are below. Use the image to decide what to keep or discard:\n',
        )
        ..write(trimmedTags);
    }

    yield* _runTask(
      sessionId: sessionId,
      taskType: taskType,
      userContent: [
        PromptAssistantContentPart.text(text.toString()),
        PromptAssistantContentPart.image(
          bytes: imageBytes,
          mimeType: _detectImageMime(imageBytes),
        ),
      ],
      userInstruction:
          'Strictly output one single-line English prompt. Do not use Markdown or explanations. Prioritize visible elements and avoid inventing unseen character information.',
    );
  }

  Stream<StreamingChunk> customPrompt(
    String currentPrompt, {
    required String sessionId,
    required String userRequest,
    List<PromptAssistantImageInput> images = const [],
  }) async* {
    final text = [
      'Current prompt:',
      currentPrompt.trim(),
      '',
      'User request:',
      userRequest.trim(),
    ].join('\n');

    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.custom,
      userContent: [
        PromptAssistantContentPart.text(text),
        for (final image in images)
          PromptAssistantContentPart.image(
            bytes: image.bytes,
            mimeType: image.mimeType,
          ),
      ],
      userInstruction:
          'Modify the current image-generation prompt according to the user request. Output only the final single-line prompt that can be used directly.',
    );
  }

  Stream<StreamingChunk> replaceCharacterPrompt(
    String input, {
    required String sessionId,
    required String characterName,
    required String characterPrompt,
  }) async* {
    final sourcePrompt = input.trim();
    final targetCharacterPrompt = characterPrompt.trim();
    AppLogger.d(
      'character replace input sourceLen=${sourcePrompt.length} targetLen=${targetCharacterPrompt.length} '
          'source="${_previewForLog(sourcePrompt)}" target="${_previewForLog(targetCharacterPrompt)}"',
      'PromptAssistant',
    );

    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.characterReplace,
      userContent: buildCharacterReplacementUserContent(
        sourcePrompt: sourcePrompt,
        characterName: characterName,
        characterPrompt: targetCharacterPrompt,
      ),
      userInstruction: characterReplacementInstruction,
    );
  }

  static const String characterReplacementInstruction =
      'Output only the complete replaced single-line English comma-separated prompt. Do not output analysis, explanations, remove/keep lists, or Markdown.';

  static String buildCharacterReplacementUserContent({
    required String sourcePrompt,
    required String characterName,
    required String characterPrompt,
  }) {
    return [
      'Source prompt to replace (use this as the main input and preserve non-character content):',
      sourcePrompt.trim(),
      '',
      'Target character name:',
      characterName.trim(),
      '',
      'Target character prompt (use only as the replacement character block):',
      characterPrompt.trim(),
    ].join('\n');
  }

  static String _previewForLog(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 240) {
      return normalized;
    }
    return '${normalized.substring(0, 240)}...';
  }

  Stream<StreamingChunk> _runTask({
    required String sessionId,
    required AssistantTaskType taskType,
    required Object userContent,
    required String userInstruction,
  }) async* {
    final config = _ref.read(promptAssistantConfigProvider);
    final execution = await _resolveTaskExecution(taskType);

    final activeRules =
        config.rules.where((r) => r.taskType == taskType && r.enabled).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final systemPrompt = [
      ...activeRules.map((e) => e.content.trim()).where((e) => e.isNotEmpty),
      userInstruction,
    ].join('\n\n');

    yield* _apiClient.complete(
      request: PromptAssistantRequest(
        sessionId: sessionId,
        responseTimeout: Duration(
          seconds: _ref
              .read(promptAssistantConfigProvider)
              .responseTimeoutSeconds,
        ),
        provider: execution.provider,
        model: execution.model.name,
        systemPrompt: systemPrompt,
        userParts: _toContentParts(userContent),
        apiKey: execution.apiKey,
      ),
    );
  }

  Future<({ProviderConfig provider, ModelConfig model, String? apiKey})>
  _resolveTaskExecution(AssistantTaskType taskType) async {
    final config = _ref.read(promptAssistantConfigProvider);
    final routingProviderId = config.routing.providerIdFor(taskType);
    final routingModel = config.routing.modelFor(taskType);
    final enabledProviders = config.providers.where((p) => p.enabled).toList();
    if (enabledProviders.isEmpty) {
      throw StateError(
        'No prompt assistant provider is available. Add and enable OpenAI, Anthropic, Gemini, DeepSeek, LM Studio, or another compatible provider in Settings first.',
      );
    }
    final provider = enabledProviders.firstWhere(
      (p) => p.id == routingProviderId,
      orElse: () => enabledProviders.first,
    );
    final taskModels = config.modelsForProviderTask(
      providerId: provider.id,
      taskType: taskType,
    );
    final hasRealModel = taskModels.any((m) => !m.isPlaceholder);
    final shouldIgnoreRoutedPlaceholder =
        (routingModel.trim().isEmpty ||
            routingModel.trim() == 'default-model') &&
        hasRealModel;
    final model = shouldIgnoreRoutedPlaceholder
        ? taskModels.firstWhere((m) => !m.isPlaceholder)
        : taskModels.firstWhere(
            (m) => m.name == routingModel,
            orElse: () => taskModels.isNotEmpty
                ? taskModels.first
                : _fallbackModelForProvider(
                    provider: provider,
                    routingModel: routingModel,
                    taskType: taskType,
                  ),
          );
    final apiKey = await _ref
        .read(promptAssistantConfigProvider.notifier)
        .getProviderApiKey(provider.id);
    return (provider: provider, model: model, apiKey: apiKey);
  }

  ModelConfig _fallbackModelForProvider({
    required ProviderConfig provider,
    required String routingModel,
    required AssistantTaskType taskType,
  }) {
    final trimmed = routingModel.trim();
    if (trimmed.isNotEmpty) {
      return ModelConfig(
        providerId: provider.id,
        name: trimmed,
        displayName: trimmed,
        forTask: taskType,
        isDefault: true,
      );
    }
    final presetModels = provider.preset?.defaultModelNames ?? const [];
    if (presetModels.isNotEmpty) {
      return ModelConfig(
        providerId: provider.id,
        name: presetModels.first,
        displayName: presetModels.first,
        forTask: taskType,
        isDefault: true,
      );
    }
    throw StateError(
      'Provider ${provider.name} has no configured model. Pull the model list or add a model manually first.',
    );
  }

  List<PromptAssistantContentPart> _toContentParts(Object userContent) {
    if (userContent is String) {
      return [PromptAssistantContentPart.text(userContent)];
    }
    if (userContent is List<PromptAssistantContentPart>) {
      return userContent;
    }
    if (userContent is List) {
      final parts = <PromptAssistantContentPart>[];
      for (final item in userContent) {
        if (item is PromptAssistantContentPart) {
          parts.add(item);
        } else if (item is Map<String, dynamic>) {
          final type = item['type'];
          if (type == 'text') {
            parts.add(PromptAssistantContentPart.text('${item['text'] ?? ''}'));
          } else if (type == 'image_url') {
            final imageUrl = item['image_url'];
            final url = imageUrl is Map ? imageUrl['url'] : null;
            if (url is String) {
              final parsed = parseDataUriImage(url);
              if (parsed != null) {
                parts.add(
                  PromptAssistantContentPart.image(
                    bytes: parsed.bytes,
                    mimeType: parsed.mimeType,
                  ),
                );
              }
            }
          }
        } else {
          final text = item.toString();
          if (text.trim().isNotEmpty) {
            parts.add(PromptAssistantContentPart.text(text));
          }
        }
      }
      return parts;
    }
    return [PromptAssistantContentPart.text(userContent.toString())];
  }

  String _detectImageMime(Uint8List bytes) {
    final detected = detectImageMime(bytes);
    if (detected != null) return detected;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
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
    return 'image/png';
  }
}
