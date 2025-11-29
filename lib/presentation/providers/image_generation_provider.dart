import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_api_service.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/tag/tag_suggestion.dart';

part 'image_generation_provider.g.dart';

/// 生成状态
enum GenerationStatus {
  idle,
  generating,
  completed,
  error,
  cancelled,
}

/// 图像生成状态
class ImageGenerationState {
  final GenerationStatus status;
  final List<Uint8List> currentImages;
  final List<Uint8List> history;
  final String? errorMessage;
  final double progress;
  final int currentImage;  // 当前第几张 (1-based)
  final int totalImages;   // 总共几张

  const ImageGenerationState({
    this.status = GenerationStatus.idle,
    this.currentImages = const [],
    this.history = const [],
    this.errorMessage,
    this.progress = 0.0,
    this.currentImage = 0,
    this.totalImages = 0,
  });

  ImageGenerationState copyWith({
    GenerationStatus? status,
    List<Uint8List>? currentImages,
    List<Uint8List>? history,
    String? errorMessage,
    double? progress,
    int? currentImage,
    int? totalImages,
  }) {
    return ImageGenerationState(
      status: status ?? this.status,
      currentImages: currentImages ?? this.currentImages,
      history: history ?? this.history,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
    );
  }

  bool get isGenerating => status == GenerationStatus.generating;
  bool get hasImages => currentImages.isNotEmpty;
}

/// 图像生成状态 Notifier
@Riverpod(keepAlive: true)
class ImageGenerationNotifier extends _$ImageGenerationNotifier {
  @override
  ImageGenerationState build() {
    return const ImageGenerationState();
  }

  /// 生成图像
  /// 重试延迟策略 (毫秒)
  static const List<int> _retryDelays = [1000, 2000, 4000];
  static const int _maxRetries = 3;
  
  bool _isCancelled = false;

  Future<void> generate(ImageParams params) async {
    _isCancelled = false;
    final totalImages = params.nSamples;
    
    // 应用质量标签（如果开启）
    final addQualityTags = ref.read(qualityTagsSettingsProvider);
    ImageParams baseParams = params;
    if (addQualityTags) {
      final enhancedPrompt = QualityTags.applyQualityTags(
        params.prompt,
        params.model,
      );
      baseParams = params.copyWith(prompt: enhancedPrompt);
    }

    // 如果只生成 1 张，直接生成
    if (totalImages == 1) {
      await _generateSingle(baseParams, 1, 1);
      return;
    }

    // 多张图片：拆分成单张请求
    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: 1,
      totalImages: totalImages,
      currentImages: [],
    );

    final allImages = <Uint8List>[];
    final random = Random();

    for (int i = 0; i < totalImages; i++) {
      if (_isCancelled) break;

      // 更新当前进度
      state = state.copyWith(
        currentImage: i + 1,
        progress: i / totalImages,
      );

      // 每张使用不同的随机种子
      final singleParams = baseParams.copyWith(
        nSamples: 1,
        seed: random.nextInt(4294967295),
      );

      try {
        final images = await _generateWithRetry(singleParams);
        if (images.isNotEmpty) {
          allImages.addAll(images);
          // 立即更新显示和历史
          state = state.copyWith(
            currentImages: List.from(allImages),
            history: [...images, ...state.history].take(50).toList(),
          );
        }
      } catch (e) {
        if (_isCancelled || e.toString().contains('cancelled')) {
          state = state.copyWith(
            status: GenerationStatus.cancelled,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
          );
          return;
        }
        // 单张失败，继续下一张
        AppLogger.e('生成第 ${i + 1} 张失败: $e');
      }
    }

    // 完成
    state = state.copyWith(
      status: _isCancelled ? GenerationStatus.cancelled : GenerationStatus.completed,
      progress: 1.0,
      currentImage: 0,
      totalImages: 0,
    );
  }

  /// 带重试的生成
  Future<List<Uint8List>> _generateWithRetry(ImageParams params) async {
    final apiService = ref.read(naiApiServiceProvider);
    
    for (int retry = 0; retry <= _maxRetries; retry++) {
      try {
        return await apiService.generateImageCancellable(
          params,
          onProgress: (received, total) {
            // 单张进度暂不更新
          },
        );
      } catch (e) {
        if (_isCancelled || e.toString().contains('cancelled')) {
          rethrow;
        }
        
        if (retry < _maxRetries) {
          AppLogger.w('生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e');
          await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
        } else {
          rethrow;
        }
      }
    }
    
    return [];
  }

  /// 生成单张（无拆分）
  Future<void> _generateSingle(ImageParams params, int current, int total) async {
    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: current,
      totalImages: total,
    );

    try {
      final images = await _generateWithRetry(params);

      state = state.copyWith(
        status: GenerationStatus.completed,
        currentImages: images,
        history: [...images, ...state.history].take(50).toList(),
        progress: 1.0,
        currentImage: 0,
        totalImages: 0,
      );
    } catch (e) {
      if (_isCancelled || e.toString().contains('cancelled')) {
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
        );
      } else {
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: e.toString(),
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
        );
      }
    }
  }

  /// 取消生成
  void cancel() {
    _isCancelled = true;
    final apiService = ref.read(naiApiServiceProvider);
    apiService.cancelGeneration();

    state = state.copyWith(
      status: GenerationStatus.cancelled,
      progress: 0.0,
      currentImage: 0,
      totalImages: 0,
    );
  }

  /// 清除当前图像
  void clearCurrent() {
    state = state.copyWith(
      currentImages: [],
      status: GenerationStatus.idle,
    );
  }

  /// 清除错误
  void clearError() {
    if (state.status == GenerationStatus.error) {
      state = state.copyWith(
        status: GenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  /// 清除历史
  void clearHistory() {
    state = state.copyWith(history: []);
  }
}

/// 图像生成参数 Notifier
@Riverpod(keepAlive: true)
class GenerationParamsNotifier extends _$GenerationParamsNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ImageParams build() {
    // 从本地存储加载默认参数和上次使用的参数
    final storage = ref.read(localStorageServiceProvider);

    return ImageParams(
      prompt: storage.getLastPrompt(),
      negativePrompt: storage.getLastNegativePrompt(),
      model: storage.getDefaultModel(),
      sampler: storage.getDefaultSampler(),
      steps: storage.getDefaultSteps(),
      scale: storage.getDefaultScale(),
      width: storage.getDefaultWidth(),
      height: storage.getDefaultHeight(),
      smea: storage.getLastSmea(),
      smeaDyn: storage.getLastSmeaDyn(),
      cfgRescale: storage.getLastCfgRescale(),
      noiseSchedule: storage.getLastNoiseSchedule(),
    );
  }

  /// 更新提示词
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
    _storage.setLastPrompt(prompt);
  }

  /// 更新负向提示词
  void updateNegativePrompt(String negativePrompt) {
    state = state.copyWith(negativePrompt: negativePrompt);
    _storage.setLastNegativePrompt(negativePrompt);
  }

  /// 更新模型
  void updateModel(String model) {
    state = state.copyWith(model: model);
    _storage.setDefaultModel(model);
  }

  /// 更新尺寸
  void updateSize(int width, int height) {
    state = state.copyWith(width: width, height: height);
    _storage.setDefaultWidth(width);
    _storage.setDefaultHeight(height);
  }

  /// 更新步数
  void updateSteps(int steps) {
    state = state.copyWith(steps: steps);
    _storage.setDefaultSteps(steps);
  }

  /// 更新 Scale
  void updateScale(double scale) {
    state = state.copyWith(scale: scale);
    _storage.setDefaultScale(scale);
  }

  /// 更新采样器
  void updateSampler(String sampler) {
    state = state.copyWith(sampler: sampler);
    _storage.setDefaultSampler(sampler);
  }

  /// 更新种子
  void updateSeed(int seed) {
    state = state.copyWith(seed: seed);
  }

  /// 随机种子
  void randomizeSeed() {
    state = state.copyWith(seed: -1);
  }

  /// 更新 SMEA
  void updateSmea(bool smea) {
    state = state.copyWith(smea: smea);
    _storage.setLastSmea(smea);
  }

  /// 更新 SMEA DYN
  void updateSmeaDyn(bool smeaDyn) {
    state = state.copyWith(smeaDyn: smeaDyn);
    _storage.setLastSmeaDyn(smeaDyn);
  }

  /// 更新 CFG Rescale
  void updateCfgRescale(double cfgRescale) {
    state = state.copyWith(cfgRescale: cfgRescale);
    _storage.setLastCfgRescale(cfgRescale);
  }

  /// 更新噪声计划
  void updateNoiseSchedule(String noiseSchedule) {
    state = state.copyWith(noiseSchedule: noiseSchedule);
    _storage.setLastNoiseSchedule(noiseSchedule);
  }

  /// 重置为默认值
  void reset() {
    final storage = ref.read(localStorageServiceProvider);

    state = ImageParams(
      model: storage.getDefaultModel(),
      sampler: storage.getDefaultSampler(),
      steps: storage.getDefaultSteps(),
      scale: storage.getDefaultScale(),
      width: storage.getDefaultWidth(),
      height: storage.getDefaultHeight(),
    );
  }

  // ==================== 生成动作 ====================

  /// 更新生成动作
  void updateAction(ImageGenerationAction action) {
    state = state.copyWith(action: action);
  }

  // ==================== img2img 参数 ====================

  /// 设置源图像
  void setSourceImage(Uint8List? image) {
    state = state.copyWith(sourceImage: image);
  }

  /// 更新强度 (img2img)
  void updateStrength(double strength) {
    state = state.copyWith(strength: strength);
  }

  /// 更新噪声 (img2img)
  void updateNoise(double noise) {
    state = state.copyWith(noise: noise);
  }

  /// 清除 img2img 设置
  void clearImg2Img() {
    state = state.copyWith(
      action: ImageGenerationAction.generate,
      sourceImage: null,
      strength: 0.7,
      noise: 0.0,
    );
  }

  // ==================== Inpainting 参数 ====================

  /// 设置蒙版图像
  void setMaskImage(Uint8List? mask) {
    state = state.copyWith(maskImage: mask);
  }

  /// 清除 Inpainting 设置
  void clearInpainting() {
    state = state.copyWith(
      action: ImageGenerationAction.generate,
      sourceImage: null,
      maskImage: null,
    );
  }

  // ==================== Vibe Transfer 参数 ====================

  /// 添加 Vibe 参考图
  void addVibeReference(VibeReference vibe) {
    if (state.vibeReferences.length >= 4) return; // 最多4张
    state = state.copyWith(
      vibeReferences: [...state.vibeReferences, vibe],
    );
  }

  /// 移除 Vibe 参考图
  void removeVibeReference(int index) {
    if (index < 0 || index >= state.vibeReferences.length) return;
    final newList = [...state.vibeReferences];
    newList.removeAt(index);
    state = state.copyWith(vibeReferences: newList);
  }

  /// 更新 Vibe 参考图配置
  void updateVibeReference(
    int index, {
    double? strength,
    double? informationExtracted,
  }) {
    if (index < 0 || index >= state.vibeReferences.length) return;
    final newList = [...state.vibeReferences];
    final current = newList[index];
    newList[index] = VibeReference(
      image: current.image,
      strength: strength ?? current.strength,
      informationExtracted:
          informationExtracted ?? current.informationExtracted,
    );
    state = state.copyWith(vibeReferences: newList);
  }

  /// 清除所有 Vibe 参考图
  void clearVibeReferences() {
    state = state.copyWith(vibeReferences: []);
  }

  // ==================== 多角色参数 (V4 模型) ====================

  /// 添加角色
  void addCharacter(CharacterPrompt character) {
    if (state.characters.length >= 6) return; // 最多6个角色
    state = state.copyWith(
      characters: [...state.characters, character],
    );
  }

  /// 移除角色
  void removeCharacter(int index) {
    if (index < 0 || index >= state.characters.length) return;
    final newList = [...state.characters];
    newList.removeAt(index);
    state = state.copyWith(characters: newList);
  }

  /// 更新角色
  void updateCharacter(int index, CharacterPrompt character) {
    if (index < 0 || index >= state.characters.length) return;
    final newList = [...state.characters];
    newList[index] = character;
    state = state.copyWith(characters: newList);
  }

  /// 清除所有角色
  void clearCharacters() {
    state = state.copyWith(characters: []);
  }

  /// 更新生成数量
  void updateNSamples(int nSamples) {
    state = state.copyWith(nSamples: nSamples < 1 ? 1 : nSamples);
  }

  // ==================== 高级参数 ====================

  /// 更新 UC 预设
  void updateUcPreset(int ucPreset) {
    state = state.copyWith(ucPreset: ucPreset.clamp(0, 7));
  }

  /// 更新质量标签开关
  void updateQualityToggle(bool qualityToggle) {
    state = state.copyWith(qualityToggle: qualityToggle);
  }

  /// 更新多样性增强 (V4+)
  void updateVarietyPlus(bool varietyPlus) {
    state = state.copyWith(varietyPlus: varietyPlus);
  }

  /// 更新使用坐标模式 (V4+ 多角色)
  void updateUseCoords(bool useCoords) {
    state = state.copyWith(useCoords: useCoords);
  }

  /// 更新添加原始图像
  void updateAddOriginalImage(bool addOriginalImage) {
    state = state.copyWith(addOriginalImage: addOriginalImage);
  }
}

// ==================== 标签建议 Provider ====================

/// 标签建议状态
class TagSuggestionState {
  final List<TagSuggestion> suggestions;
  final bool isLoading;
  final String? error;

  const TagSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  TagSuggestionState copyWith({
    List<TagSuggestion>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return TagSuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 标签建议 Notifier
@riverpod
class TagSuggestionNotifier extends _$TagSuggestionNotifier {
  Timer? _debounceTimer;

  @override
  TagSuggestionState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const TagSuggestionState();
  }

  /// 获取标签建议 (带防抖)
  void fetchSuggestions(String input, {String? model}) {
    _debounceTimer?.cancel();

    if (input.trim().length < 2) {
      state = const TagSuggestionState();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      state = state.copyWith(isLoading: true, error: null);

      try {
        final apiService = ref.read(naiApiServiceProvider);
        final suggestions = await apiService.suggestTags(input, model: model);
        state = state.copyWith(
          suggestions: suggestions,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    });
  }

  /// 清除建议
  void clearSuggestions() {
    _debounceTimer?.cancel();
    state = const TagSuggestionState();
  }
}

// ==================== 图片放大 Provider ====================

/// 放大状态
enum UpscaleStatus {
  idle,
  processing,
  completed,
  error,
}

/// 放大状态
class UpscaleState {
  final UpscaleStatus status;
  final Uint8List? result;
  final String? error;
  final double progress;

  const UpscaleState({
    this.status = UpscaleStatus.idle,
    this.result,
    this.error,
    this.progress = 0.0,
  });

  UpscaleState copyWith({
    UpscaleStatus? status,
    Uint8List? result,
    String? error,
    double? progress,
  }) {
    return UpscaleState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// 放大 Notifier
@riverpod
class UpscaleNotifier extends _$UpscaleNotifier {
  @override
  UpscaleState build() {
    return const UpscaleState();
  }

  /// 放大图像
  Future<void> upscale(Uint8List image, {int scale = 2}) async {
    state = state.copyWith(
      status: UpscaleStatus.processing,
      progress: 0.0,
      error: null,
      result: null,
    );

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final result = await apiService.upscaleImage(
        image,
        scale: scale,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(
        status: UpscaleStatus.completed,
        result: result,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpscaleStatus.error,
        error: e.toString(),
        progress: 0.0,
      );
    }
  }

  /// 清除结果
  void clear() {
    state = const UpscaleState();
  }
}

/// 质量标签设置 Notifier
@Riverpod(keepAlive: true)
class QualityTagsSettings extends _$QualityTagsSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getAddQualityTags();
  }

  /// 切换质量标签开关
  void toggle() {
    state = !state;
    _storage.setAddQualityTags(state);
  }

  /// 设置质量标签开关
  void set(bool value) {
    state = value;
    _storage.setAddQualityTags(value);
  }
}

/// 自动补全设置 Notifier
@Riverpod(keepAlive: true)
class AutocompleteSettings extends _$AutocompleteSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getEnableAutocomplete();
  }

  /// 切换自动补全开关
  void toggle() {
    state = !state;
    _storage.setEnableAutocomplete(state);
  }

  /// 设置自动补全开关
  void set(bool value) {
    state = value;
    _storage.setEnableAutocomplete(value);
  }
}

/// 自动格式化设置 Notifier
@Riverpod(keepAlive: true)
class AutoFormatPromptSettings extends _$AutoFormatPromptSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getAutoFormatPrompt();
  }

  /// 切换自动格式化开关
  void toggle() {
    state = !state;
    _storage.setAutoFormatPrompt(state);
  }

  /// 设置自动格式化开关
  void set(bool value) {
    state = value;
    _storage.setAutoFormatPrompt(value);
  }
}
