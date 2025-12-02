import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_api_service.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/image/image_stream_chunk.dart';
import '../../data/models/tag/tag_suggestion.dart';
import '../../data/models/vibe/vibe_reference_v4.dart';
import 'prompt_config_provider.dart';
import 'subscription_provider.dart';

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
  final int currentImage; // 当前第几张 (1-based)
  final int totalImages; // 总共几张

  /// 流式预览图像（渐进式生成过程中的预览）
  final Uint8List? streamPreview;

  const ImageGenerationState({
    this.status = GenerationStatus.idle,
    this.currentImages = const [],
    this.history = const [],
    this.errorMessage,
    this.progress = 0.0,
    this.currentImage = 0,
    this.totalImages = 0,
    this.streamPreview,
  });

  ImageGenerationState copyWith({
    GenerationStatus? status,
    List<Uint8List>? currentImages,
    List<Uint8List>? history,
    String? errorMessage,
    double? progress,
    int? currentImage,
    int? totalImages,
    Uint8List? streamPreview,
    bool clearStreamPreview = false,
  }) {
    return ImageGenerationState(
      status: status ?? this.status,
      currentImages: currentImages ?? this.currentImages,
      history: history ?? this.history,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
      streamPreview: clearStreamPreview ? null : (streamPreview ?? this.streamPreview),
    );
  }

  bool get isGenerating => status == GenerationStatus.generating;
  bool get hasImages => currentImages.isNotEmpty;

  /// 是否有流式预览图像
  bool get hasStreamPreview => streamPreview != null && streamPreview!.isNotEmpty;
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
    
    // 开始生成前清空当前图片
    state = state.copyWith(
      currentImages: [],
      status: GenerationStatus.generating,
    );
    
    // nSamples = 批次数量（请求次数）
    // batchSize = 每次请求生成的图片数量
    final batchCount = params.nSamples;
    final batchSize = ref.read(imagesPerRequestProvider);
    final totalImages = batchCount * batchSize;

    // 读取 UI 设置，转换为 API 参数
    // 质量标签：由 API 的 qualityToggle 参数控制，后端自动添加
    final addQualityTags = ref.read(qualityTagsSettingsProvider);

    // UC 预设：由 API 的 ucPreset 参数控制，后端自动填充负向提示词
    // UcPresetType.heavy -> 0, light -> 1, humanFocus -> 2, none -> 3
    final ucPresetType = ref.read(ucPresetSettingsProvider);
    final ucPresetValue = ucPresetType.index; // enum index 正好对应 API 值

    // 将设置应用到参数（不在客户端修改提示词内容，让后端处理）
    ImageParams baseParams = params.copyWith(
      qualityToggle: addQualityTags,
      ucPreset: ucPresetValue,
    );

    // 如果只生成 1 张，直接生成
    if (batchCount == 1 && batchSize == 1) {
      await _generateSingle(baseParams, 1, 1);
      // 单抽完成后，如果开启抽卡模式，也要随机新提示词
      final randomMode = ref.read(randomPromptModeProvider);
      if (randomMode) {
        final randomPrompt = ref.read(promptConfigNotifierProvider.notifier).generatePrompt();
        if (randomPrompt.isNotEmpty) {
          debugPrint('[RandomMode] Single - New prompt for next generation: $randomPrompt');
          ref.read(generationParamsNotifierProvider.notifier).updatePrompt(randomPrompt);
        }
      }
      return;
    }

    // 获取抽卡模式设置
    final randomMode = ref.read(randomPromptModeProvider);
    
    // 多张图片：按批次循环请求
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
    int generatedImages = 0;
    
    // 当前使用的参数（可能会被抽卡模式修改）
    ImageParams currentParams = baseParams;

    for (int batch = 0; batch < batchCount; batch++) {
      if (_isCancelled) break;

      // 更新当前进度
      state = state.copyWith(
        currentImage: generatedImages + 1,
        progress: generatedImages / totalImages,
      );

      // 每批使用不同的随机种子
      final batchParams = currentParams.copyWith(
        nSamples: batchSize,
        seed: random.nextInt(4294967295),
      );

      try {
        final images = await _generateWithRetry(batchParams);
        if (images.isNotEmpty) {
          allImages.addAll(images);
          generatedImages += images.length;
          // 立即更新显示和历史
          state = state.copyWith(
            currentImages: List.from(allImages),
            history: [...images, ...state.history].take(50).toList(),
          );
          
          // 如果开启抽卡模式，每批生成后随机新提示词
          if (randomMode && batch < batchCount - 1) {
            final randomPrompt = ref.read(promptConfigNotifierProvider.notifier).generatePrompt();
            if (randomPrompt.isNotEmpty) {
              debugPrint('[RandomMode] Batch ${batch + 1}/$batchCount - New prompt: $randomPrompt');
              // 更新 UI 中的提示词
              ref.read(generationParamsNotifierProvider.notifier).updatePrompt(randomPrompt);
              // 更新下一批次使用的参数（质量标签由后端通过 qualityToggle 自动添加）
              currentParams = currentParams.copyWith(prompt: randomPrompt);
            }
          }
        } else {
          generatedImages += batchSize; // 即使失败也要跳过，避免死循环
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
        // 本批次失败，继续下一批
        AppLogger.e('生成第 ${batch + 1} 批失败: $e');
        generatedImages += batchSize;
      }
    }
    
    // 生成完成后，如果开启抽卡模式，再随机一次（为下次点击生成做准备）
    if (randomMode) {
      final randomPrompt = ref.read(promptConfigNotifierProvider.notifier).generatePrompt();
      if (randomPrompt.isNotEmpty) {
        debugPrint('[RandomMode] Final - New prompt for next generation: $randomPrompt');
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(randomPrompt);
      }
    }

    // 完成
    state = state.copyWith(
      status: _isCancelled
          ? GenerationStatus.cancelled
          : GenerationStatus.completed,
      progress: 1.0,
      currentImage: 0,
      totalImages: 0,
    );

    // 生成完成后刷新 Anlas 余额
    ref.read(subscriptionNotifierProvider.notifier).refreshBalance();
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
          AppLogger.w(
              '生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e');
          await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
        } else {
          rethrow;
        }
      }
    }

    return [];
  }

  /// 生成单张（使用流式 API 支持渐进式预览）
  Future<void> _generateSingle(
      ImageParams params, int current, int total) async {
    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: current,
      totalImages: total,
      clearStreamPreview: true,
    );

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final stream = apiService.generateImageStream(params);

      Uint8List? finalImage;

      await for (final chunk in stream) {
        if (_isCancelled) {
          state = state.copyWith(
            status: GenerationStatus.cancelled,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
          return;
        }

        if (chunk.hasError) {
          state = state.copyWith(
            status: GenerationStatus.error,
            errorMessage: chunk.error,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
          return;
        }

        if (chunk.hasPreview) {
          // 更新流式预览
          state = state.copyWith(
            progress: chunk.progress,
            streamPreview: chunk.previewImage,
          );
        }

        if (chunk.isComplete && chunk.hasFinalImage) {
          finalImage = chunk.finalImage;
        }
      }

      if (finalImage != null) {
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: [finalImage],
          history: [finalImage, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      } else {
        // 流式 API 未返回图像，回退到非流式 API
        AppLogger.w('Stream API returned no image, falling back to non-stream API', 'Generation');
        final images = await _generateWithRetry(params);
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: images,
          history: [...images, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      }
    } catch (e) {
      if (_isCancelled || e.toString().contains('cancelled')) {
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      } else {
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: e.toString(),
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
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

  /// 更新 SMEA Auto (V3 模型)
  void updateSmeaAuto(bool smeaAuto) {
    state = state.copyWith(smeaAuto: smeaAuto);
  }

  /// 更新 SMEA (V3 模型)
  void updateSmea(bool smea) {
    state = state.copyWith(smea: smea);
    _storage.setLastSmea(smea);
  }

  /// 更新 SMEA DYN (V3 模型)
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
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReference(VibeReference vibe) {
    if (state.vibeReferences.length >= 4) return; // 最多4张
    state = state.copyWith(
      vibeReferences: [...state.vibeReferences, vibe],
      characterReferences: [], // 互斥：清除角色参考
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

  // ==================== V4 Vibe Transfer 参数 ====================

  /// 添加 V4 Vibe 参考
  /// 支持预编码 (.naiv4vibe, PNG 带元数据) 和原始图片
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReferenceV4(VibeReferenceV4 vibe) {
    if (state.vibeReferencesV4.length >= 16) return; // V4 支持最多 16 张
    state = state.copyWith(
      vibeReferencesV4: [...state.vibeReferencesV4, vibe],
      characterReferences: [], // 互斥：清除角色参考
    );
  }

  /// 批量添加 V4 Vibe 参考
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReferencesV4(List<VibeReferenceV4> vibes) {
    final remaining = 16 - state.vibeReferencesV4.length;
    if (remaining <= 0) return;

    final toAdd = vibes.take(remaining).toList();
    state = state.copyWith(
      vibeReferencesV4: [...state.vibeReferencesV4, ...toAdd],
      characterReferences: [], // 互斥：清除角色参考
    );
  }

  /// 移除 V4 Vibe 参考
  void removeVibeReferenceV4(int index) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    newList.removeAt(index);
    state = state.copyWith(vibeReferencesV4: newList);
  }

  /// 更新 V4 Vibe 参考配置
  void updateVibeReferenceV4(
    int index, {
    double? strength,
    double? infoExtracted,
  }) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    final current = newList[index];
    newList[index] = current.copyWith(
      strength: strength ?? current.strength,
      infoExtracted: infoExtracted ?? current.infoExtracted,
    );
    state = state.copyWith(vibeReferencesV4: newList);
  }

  /// 清除所有 V4 Vibe 参考
  void clearVibeReferencesV4() {
    state = state.copyWith(vibeReferencesV4: []);
  }

  /// 设置 Vibe 强度标准化开关
  void setNormalizeVibeStrength(bool value) {
    state = state.copyWith(normalizeVibeStrength: value);
  }

  // ==================== 角色参考参数 (V4+ 模型) ====================

  /// 添加角色参考图
  /// 注意：角色参考最多4张，且和 Vibe Transfer 互斥
  void addCharacterReference(CharacterReference ref) {
    if (state.characterReferences.length >= 4) return; // 最多4张
    state = state.copyWith(
      characterReferences: [...state.characterReferences, ref],
      vibeReferences: [], // 清除 Vibe Transfer（互斥）
      vibeReferencesV4: [], // 清除 V4 Vibe Transfer（互斥）
    );
  }

  /// 移除角色参考图
  void removeCharacterReference(int index) {
    if (index < 0 || index >= state.characterReferences.length) return;
    final newList = [...state.characterReferences];
    newList.removeAt(index);
    state = state.copyWith(characterReferences: newList);
  }

  /// 更新角色参考图配置
  void updateCharacterReference(
    int index, {
    String? description,
    double? informationExtracted,
    double? strengthValue,
    double? secondaryStrength,
  }) {
    if (index < 0 || index >= state.characterReferences.length) return;
    final newList = [...state.characterReferences];
    final current = newList[index];
    newList[index] = CharacterReference(
      image: current.image,
      description: description ?? current.description,
      informationExtracted: informationExtracted ?? current.informationExtracted,
      strengthValue: strengthValue ?? current.strengthValue,
      secondaryStrength: secondaryStrength ?? current.secondaryStrength,
    );
    state = state.copyWith(characterReferences: newList);
  }

  /// 清除所有角色参考图
  void clearCharacterReferences() {
    state = state.copyWith(characterReferences: []);
  }

  /// 更新是否标准化角色参考强度
  void setNormalizeCharacterReferenceStrength(bool value) {
    state = state.copyWith(normalizeCharacterReferenceStrength: value);
  }

  /// 更新角色参考 Style Aware 开关
  void setCharacterReferenceStyleAware(bool value) {
    state = state.copyWith(characterReferenceStyleAware: value);
  }

  /// 更新角色参考 Fidelity 值
  void setCharacterReferenceFidelity(double value) {
    state = state.copyWith(characterReferenceFidelity: value.clamp(0.0, 1.0));
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

  /// 更新 Decrisp (V3 模型)
  void updateDecrisp(bool decrisp) {
    state = state.copyWith(decrisp: decrisp);
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

/// 高亮强调设置 Notifier
@Riverpod(keepAlive: true)
class HighlightEmphasisSettings extends _$HighlightEmphasisSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getHighlightEmphasis();
  }

  /// 切换高亮强调开关
  void toggle() {
    state = !state;
    _storage.setHighlightEmphasis(state);
  }

  /// 设置高亮强调开关
  void set(bool value) {
    state = value;
    _storage.setHighlightEmphasis(value);
  }
}

/// SD语法自动转换设置 Notifier
@Riverpod(keepAlive: true)
class SdSyntaxAutoConvertSettings extends _$SdSyntaxAutoConvertSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getSdSyntaxAutoConvert();
  }

  /// 切换SD语法自动转换开关
  void toggle() {
    state = !state;
    _storage.setSdSyntaxAutoConvert(state);
  }

  /// 设置SD语法自动转换开关
  void set(bool value) {
    state = value;
    _storage.setSdSyntaxAutoConvert(value);
  }
}

/// 负面提示词预设设置 Notifier
@Riverpod(keepAlive: true)
class UcPresetSettings extends _$UcPresetSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  UcPresetType build() {
    final index = _storage.getUcPresetType();
    if (index >= 0 && index < UcPresetType.values.length) {
      return UcPresetType.values[index];
    }
    return UcPresetType.heavy; // 默认使用 Heavy
  }

  /// 设置预设类型
  void set(UcPresetType type) {
    state = type;
    _storage.setUcPresetType(type.index);
  }
}

/// 抽卡模式设置 Notifier（生成时自动随机提示词）
@Riverpod(keepAlive: true)
class RandomPromptMode extends _$RandomPromptMode {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getRandomPromptMode();
  }

  /// 切换抽卡模式
  void toggle() {
    state = !state;
    _storage.setRandomPromptMode(state);
  }

  /// 设置抽卡模式
  void set(bool value) {
    state = value;
    _storage.setRandomPromptMode(value);
  }
}

/// 每次请求生成图片数量设置 Notifier（1-4张）
@Riverpod(keepAlive: true)
class ImagesPerRequest extends _$ImagesPerRequest {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  int build() {
    return _storage.getImagesPerRequest();
  }

  /// 设置每次请求数量
  void set(int value) {
    state = value.clamp(1, 4);
    _storage.setImagesPerRequest(state);
  }
}
