import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/character/character_prompt.dart';
import '../../data/services/local_onnx_model_service.dart';
import '../../data/services/local_onnx_tagger_service.dart';
import '../prompt_assistant/models/prompt_assistant_models.dart';
import '../prompt_assistant/services/prompt_assistant_service.dart';
import '../utils/reverse_prompt_image_normalizer.dart';

final reversePromptProvider =
    StateNotifierProvider<ReversePromptNotifier, ReversePromptState>((ref) {
  return ReversePromptNotifier(ref);
});

final reversePromptCharacterProvider = StateNotifierProvider<
    ReversePromptCharacterNotifier, CharacterPromptConfig>((ref) {
  return ReversePromptCharacterNotifier(ref);
});

class ReversePromptCharacterNotifier
    extends StateNotifier<CharacterPromptConfig> {
  ReversePromptCharacterNotifier(this._ref)
      : super(const CharacterPromptConfig()) {
    _load();
  }

  final Ref _ref;

  LocalStorageService get _storage => _ref.read(localStorageServiceProvider);

  CharacterPrompt? get selectedCharacter {
    for (final character in state.characters) {
      if (character.enabled && character.prompt.trim().isNotEmpty) {
        return character;
      }
    }
    return null;
  }

  void _load() {
    final raw = _storage
        .getSetting<String>(StorageKeys.reversePromptCharacterConfigJson);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = CharacterPromptConfig.fromJson(decoded);
    } catch (_) {
      state = const CharacterPromptConfig();
    }
  }

  Future<void> _save() async {
    await _storage.setSetting(
      StorageKeys.reversePromptCharacterConfigJson,
      jsonEncode(state.toJson()),
    );
  }

  void setReplacementCharacter(CharacterPrompt character) {
    state = CharacterPromptConfig(
      characters: [
        character.copyWith(enabled: true),
      ],
    );
    _save();
  }

  void clearReplacementCharacter() {
    state = const CharacterPromptConfig();
    _save();
  }
}

class ReversePromptImage {
  const ReversePromptImage({
    required this.id,
    required this.bytes,
    this.name,
  });

  final String id;
  final Uint8List bytes;
  final String? name;
}

enum ReversePromptProcessingStage {
  preparing,
  onnxTagger,
  llmReverse,
  characterReplace,
}

class _ReversePromptUiError implements Exception {
  const _ReversePromptUiError(this.key);

  final String key;
}

class ReversePromptState {
  const ReversePromptState({
    this.images = const [],
    this.useOnnxTagger = true,
    this.useLlmReverse = true,
    this.useCharacterReplace = false,
    this.selectedTaggerModelPath,
    this.selectedCharacterId,
    this.taggerGeneralThreshold = 0.35,
    this.taggerCharacterThreshold = 0.35,
    this.taggerPrompt = '',
    this.llmPrompt = '',
    this.characterReplacePrompt = '',
    this.finalPrompt = '',
    this.isProcessing = false,
    this.processingStage,
    this.error,
  });

  final List<ReversePromptImage> images;
  final bool useOnnxTagger;
  final bool useLlmReverse;
  final bool useCharacterReplace;
  final String? selectedTaggerModelPath;
  final String? selectedCharacterId;
  final double taggerGeneralThreshold;
  final double taggerCharacterThreshold;
  final String taggerPrompt;
  final String llmPrompt;
  final String characterReplacePrompt;
  final String finalPrompt;
  final bool isProcessing;
  final ReversePromptProcessingStage? processingStage;
  final String? error;

  bool get canRun => images.isNotEmpty && (useOnnxTagger || useLlmReverse);

  ReversePromptState copyWith({
    List<ReversePromptImage>? images,
    bool? useOnnxTagger,
    bool? useLlmReverse,
    bool? useCharacterReplace,
    String? selectedTaggerModelPath,
    bool clearSelectedTaggerModelPath = false,
    String? selectedCharacterId,
    bool clearSelectedCharacterId = false,
    double? taggerGeneralThreshold,
    double? taggerCharacterThreshold,
    String? taggerPrompt,
    String? llmPrompt,
    String? characterReplacePrompt,
    String? finalPrompt,
    bool? isProcessing,
    ReversePromptProcessingStage? processingStage,
    bool clearProcessingStage = false,
    String? error,
    bool clearError = false,
  }) {
    return ReversePromptState(
      images: images ?? this.images,
      useOnnxTagger: useOnnxTagger ?? this.useOnnxTagger,
      useLlmReverse: useLlmReverse ?? this.useLlmReverse,
      useCharacterReplace: useCharacterReplace ?? this.useCharacterReplace,
      selectedTaggerModelPath: clearSelectedTaggerModelPath
          ? null
          : selectedTaggerModelPath ?? this.selectedTaggerModelPath,
      selectedCharacterId: clearSelectedCharacterId
          ? null
          : selectedCharacterId ?? this.selectedCharacterId,
      taggerGeneralThreshold:
          taggerGeneralThreshold ?? this.taggerGeneralThreshold,
      taggerCharacterThreshold:
          taggerCharacterThreshold ?? this.taggerCharacterThreshold,
      taggerPrompt: taggerPrompt ?? this.taggerPrompt,
      llmPrompt: llmPrompt ?? this.llmPrompt,
      characterReplacePrompt:
          characterReplacePrompt ?? this.characterReplacePrompt,
      finalPrompt: finalPrompt ?? this.finalPrompt,
      isProcessing: isProcessing ?? this.isProcessing,
      processingStage:
          clearProcessingStage ? null : processingStage ?? this.processingStage,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, dynamic> toPersistedJson() => {
        'useOnnxTagger': useOnnxTagger,
        'useLlmReverse': useLlmReverse,
        'useCharacterReplace': useCharacterReplace,
        'selectedTaggerModelPath': selectedTaggerModelPath,
        'selectedCharacterId': selectedCharacterId,
        'taggerGeneralThreshold': taggerGeneralThreshold,
        'taggerCharacterThreshold': taggerCharacterThreshold,
      };

  factory ReversePromptState.fromPersistedJson(Map<String, dynamic> json) {
    final useOnnx = json['useOnnxTagger'] as bool? ?? true;
    final useLlm = json['useLlmReverse'] as bool? ?? true;
    return ReversePromptState(
      useOnnxTagger: useOnnx || !useLlm,
      useLlmReverse: useLlm || !useOnnx,
      useCharacterReplace: json['useCharacterReplace'] as bool? ?? false,
      selectedTaggerModelPath: json['selectedTaggerModelPath'] as String?,
      selectedCharacterId: json['selectedCharacterId'] as String?,
      taggerGeneralThreshold:
          (json['taggerGeneralThreshold'] as num?)?.toDouble() ??
              (json['taggerThreshold'] as num?)?.toDouble() ??
              0.35,
      taggerCharacterThreshold:
          (json['taggerCharacterThreshold'] as num?)?.toDouble() ??
              (json['taggerThreshold'] as num?)?.toDouble() ??
              0.35,
    );
  }
}

class ReversePromptNotifier extends StateNotifier<ReversePromptState> {
  ReversePromptNotifier(this._ref) : super(const ReversePromptState()) {
    _load();
  }

  final Ref _ref;

  LocalStorageService get _storage => _ref.read(localStorageServiceProvider);

  void _load() {
    final raw = _storage.getSetting<String>(StorageKeys.reversePromptStateJson);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = ReversePromptState.fromPersistedJson(decoded);
    } catch (_) {
      state = const ReversePromptState();
    }
  }

  Future<void> _save() async {
    await _storage.setSetting(
      StorageKeys.reversePromptStateJson,
      jsonEncode(state.toPersistedJson()),
    );
  }

  Future<void> addImage(Uint8List bytes, {String? name}) async {
    final normalizedBytes = await _normalizeImage(bytes);
    final next = ReversePromptImage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bytes: normalizedBytes,
      name: name,
    );
    state = state.copyWith(
      images: [...state.images, next],
      clearError: true,
    );
  }

  Future<Uint8List> _normalizeImage(Uint8List bytes) async {
    try {
      return await ReversePromptImageNormalizer.normalize(bytes);
    } catch (_) {
      return bytes;
    }
  }

  void removeImage(String id) {
    state =
        state.copyWith(images: state.images.where((e) => e.id != id).toList());
  }

  void clearImages() {
    state = state.copyWith(images: const []);
  }

  Future<void> setUseOnnxTagger(bool value) async {
    if (!value && !state.useLlmReverse) {
      state = state.copyWith(useOnnxTagger: true);
      return;
    }
    state = state.copyWith(useOnnxTagger: value);
    await _save();
  }

  Future<void> setUseLlmReverse(bool value) async {
    if (!value && !state.useOnnxTagger) {
      state = state.copyWith(useLlmReverse: true);
      return;
    }
    state = state.copyWith(useLlmReverse: value);
    await _save();
  }

  Future<void> setUseCharacterReplace(bool value) async {
    state = state.copyWith(useCharacterReplace: value);
    await _save();
  }

  Future<void> setSelectedTaggerModelPath(String? value) async {
    state = state.copyWith(
      selectedTaggerModelPath: value,
      clearSelectedTaggerModelPath: value == null,
    );
    await _save();
  }

  Future<void> setSelectedCharacterId(String? value) async {
    state = state.copyWith(
      selectedCharacterId: value,
      clearSelectedCharacterId: value == null,
    );
    await _save();
  }

  Future<void> setTaggerGeneralThreshold(double value) async {
    state = state.copyWith(
      taggerGeneralThreshold: value.clamp(0.05, 0.95).toDouble(),
    );
    await _save();
  }

  Future<void> setTaggerCharacterThreshold(double value) async {
    state = state.copyWith(
      taggerCharacterThreshold: value.clamp(0.05, 0.95).toDouble(),
    );
    await _save();
  }

  Future<void> runChain() async {
    if (!state.canRun) {
      state = state.copyWith(error: 'reversePrompt_needImageAndMethod');
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      processingStage: ReversePromptProcessingStage.preparing,
      taggerPrompt: '',
      llmPrompt: '',
      characterReplacePrompt: '',
      finalPrompt: '',
      clearError: true,
    );

    try {
      var currentPrompt = '';
      final image = state.images.first;
      if (state.useOnnxTagger) {
        state = state.copyWith(
          processingStage: ReversePromptProcessingStage.onnxTagger,
        );
        final model = await _resolveSelectedTaggerModel();
        final result = await _ref.read(localOnnxTaggerServiceProvider).tagImage(
              imageBytes: image.bytes,
              model: model,
              generalThreshold: state.taggerGeneralThreshold,
              characterThreshold: state.taggerCharacterThreshold,
            );
        currentPrompt = result.prompt;
        state = state.copyWith(
          taggerPrompt: currentPrompt,
          finalPrompt: currentPrompt,
          selectedTaggerModelPath: model.path,
        );
        await _save();
      }

      if (state.useLlmReverse) {
        state = state.copyWith(
          processingStage: ReversePromptProcessingStage.llmReverse,
        );
        currentPrompt = await _collectStream(
          _ref.read(promptAssistantServiceProvider).reverseImagePrompt(
                image.bytes,
                sessionId: 'reverse_prompt_panel',
                taggerPrompt: currentPrompt,
              ),
        );
        state = state.copyWith(
          llmPrompt: currentPrompt,
          finalPrompt: currentPrompt,
        );
      }

      if (state.useCharacterReplace) {
        final character = _resolveSelectedCharacter();
        if (character == null || character.prompt.trim().isEmpty) {
          throw const _ReversePromptUiError(
            'reversePrompt_needReplacementCharacter',
          );
        }
        if (currentPrompt.trim().isEmpty) {
          throw const _ReversePromptUiError(
            'reversePrompt_needPromptForCharacterReplace',
          );
        }
        state = state.copyWith(
          processingStage: ReversePromptProcessingStage.characterReplace,
        );
        currentPrompt = await _runCharacterReplace(
          inputPrompt: currentPrompt,
          character: character,
        );
        state = state.copyWith(
          characterReplacePrompt: currentPrompt,
          finalPrompt: currentPrompt,
        );
      }

      state = state.copyWith(
        isProcessing: false,
        clearProcessingStage: true,
        finalPrompt: currentPrompt,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        clearProcessingStage: true,
        error: e is _ReversePromptUiError ? e.key : e.toString(),
      );
    }
  }

  Future<LocalOnnxModelDescriptor> _resolveSelectedTaggerModel() async {
    final models =
        await _ref.read(localOnnxModelServiceProvider).scanTaggerModels();
    if (models.isEmpty) {
      throw const _ReversePromptUiError('reversePrompt_noOnnxModel');
    }
    final selectedPath = state.selectedTaggerModelPath;
    if (selectedPath != null) {
      for (final model in models) {
        if (model.path == selectedPath) {
          return model;
        }
      }
    }
    return models.first;
  }

  CharacterPrompt? _resolveSelectedCharacter() {
    return _ref.read(reversePromptCharacterProvider.notifier).selectedCharacter;
  }

  Future<String> _runCharacterReplace({
    required String inputPrompt,
    required CharacterPrompt character,
  }) {
    return _collectStream(
      _ref.read(promptAssistantServiceProvider).replaceCharacterPrompt(
            inputPrompt,
            sessionId: 'reverse_prompt_character_replace',
            characterName: character.name,
            characterPrompt: character.prompt,
          ),
    );
  }

  Future<String> _collectStream(Stream<StreamingChunk> stream) async {
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      if (!chunk.done && chunk.delta.isNotEmpty) {
        buffer.write(chunk.delta);
      }
    }
    return buffer.toString().trim();
  }
}
