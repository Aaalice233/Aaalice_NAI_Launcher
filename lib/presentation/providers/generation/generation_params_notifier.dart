import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../auth_provider.dart';
import '../quality_preset_provider.dart';
import '../subscription_provider.dart';
import '../uc_preset_provider.dart';
import 'generation_params_persistence_service.dart';
import 'vibe_reference_service.dart';

part 'generation_params_notifier.g.dart';

/// 图像生成参数 Notifier
@Riverpod(keepAlive: true)
class GenerationParamsNotifier extends _$GenerationParamsNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  late final GenerationParamsPersistenceService _persistence;
  VibeReferenceService? _vibeReferenceService;
  VibeReferenceService get _vibeReferences =>
      _vibeReferenceService ??= _createVibeReferenceService();
  SubscriptionNotifier? _subscriptionNotifier;
  Future<void>? _generationStateRestoreInFlight;
  bool _hasAppliedGenerationStateRestore = false;
  bool _isDisposed = false;

  /// 获取最近使用的 Vibes (最多 5 个用于显示)
  List<VibeLibraryEntry> get recentVibes => _vibeReferences.recentVibes;

  GenerationStateSnapshot get _generationStateSnapshot =>
      GenerationStateSnapshot(
        vibeReferences: state.vibeReferencesV4,
        preciseReferences: state.preciseReferences,
        normalizeVibeStrength: state.normalizeVibeStrength,
      );

  void _scheduleGenerationStateSave({bool immediate = false}) {
    _persistence.scheduleSave(_generationStateSnapshot, immediate: immediate);
  }

  /// 加载最近使用的 Vibes
  Future<void> loadRecentVibes() async {
    await _vibeReferences.loadRecent();
    if (!_isDisposed) state = state.copyWith();
  }

  /// 记录 Vibe 使用并更新最近列表
  Future<void> _recordVibeUsage(VibeReference vibe) async {
    await _vibeReferences.recordUsage(vibe);
    if (!_isDisposed) state = state.copyWith();
  }

  VibeReferenceService _createVibeReferenceService({
    VibeLibraryStorageService? libraryStorage,
  }) {
    return VibeReferenceService(
      libraryStorage:
          libraryStorage ?? ref.read(vibeLibraryStorageServiceProvider),
      enhancementApi: ref.read(naiImageEnhancementApiServiceProvider),
      requestEncodingAuthentication: () =>
          !_isDisposed &&
          requireAuthenticatedAction(ref, AuthPromptReason.vibeEncoding),
      preparePostBillingRefresh: _captureBillingNotifier,
      schedulePostBillingRefresh: () {
        if (!_isDisposed) {
          _subscriptionNotifier?.schedulePostBillingRefresh();
        }
      },
    );
  }

  @override
  ImageParams build() {
    final referenceStorage = ref.read(vibeLibraryStorageServiceProvider);
    _persistence = GenerationParamsPersistenceService(
      localStorage: ref.read(localStorageServiceProvider),
      referenceStorage: referenceStorage,
    );
    _vibeReferenceService = _createVibeReferenceService(
      libraryStorage: referenceStorage,
    );
    ref.onDispose(() {
      _isDisposed = true;
      _persistence.dispose();
    });

    final initialState = _persistence.buildDefaults();
    Future.microtask(restoreGenerationState);
    return initialState;
  }

  void _captureBillingNotifier() {
    if (!_isDisposed && _subscriptionNotifier == null) {
      _subscriptionNotifier = ref.read(subscriptionNotifierProvider.notifier);
    }
  }

  // ==================== 种子锁定 ====================

  /// 获取种子是否锁定
  bool get isSeedLocked => _storage.getSeedLocked();

  /// 切换种子锁定状态
  void toggleSeedLock() {
    final wasLocked = _storage.getSeedLocked();
    final newLocked = !wasLocked;

    if (newLocked) {
      // 锁定：保存当前种子值（如果是-1则生成新种子）
      final currentSeed = state.seed;
      final seedToLock = currentSeed == -1
          ? Random().nextInt(4294967295)
          : currentSeed;
      _storage.setLockedSeedValue(seedToLock);
      _storage.setSeedLocked(true);
      state = state.copyWith(seed: seedToLock);
    } else {
      // 解锁：保留当前种子值，只取消锁定状态
      _storage.setSeedLocked(false);
      _storage.setLockedSeedValue(null);
      // 触发 state 变化以刷新 UI（保持种子值不变）
      state = state.copyWith();
    }
  }

  /// 更新提示词
  void updatePrompt(String prompt) {
    final storage = _storage;
    // 使用 Future.microtask 延迟更新，避免在 widget tree 构建期间修改 provider
    Future.microtask(() {
      if (_isDisposed) return;
      state = state.copyWith(prompt: prompt);
      storage.setLastPrompt(prompt);
    });
  }

  /// 更新负向提示词
  void updateNegativePrompt(String negativePrompt) {
    final storage = _storage;
    // 使用 Future.microtask 延迟更新，避免在 widget tree 构建期间修改 provider
    Future.microtask(() {
      if (_isDisposed) return;
      state = state.copyWith(negativePrompt: negativePrompt);
      storage.setLastNegativePrompt(negativePrompt);
    });
  }

  /// 更新模型
  ///
  /// [followDefaults] 为 true 时，若 CFG 与步数仍停留在旧模型的出厂默认值，
  /// 会一并切到新模型的默认值；用户手动调过的参数不会被覆盖。元数据导入等
  /// 需要还原历史参数的场景应传 false。
  void updateModel(
    String model, {
    bool persist = true,
    bool followDefaults = true,
  }) {
    final previousModel = state.model;
    var next = state.copyWith(model: model);

    final followUps = followDefaults
        ? resolveModelSwitchFollowUps(
            from: ModelCapabilityRegistry.of(previousModel),
            to: ModelCapabilityRegistry.of(model),
            currentScale: state.scale,
            currentSteps: state.steps,
            currentNoiseSchedule: state.noiseSchedule,
            currentVarietyPlus: state.varietyPlus,
          )
        : const ModelSwitchFollowUps();

    if (followUps.scale != null) {
      next = next.copyWith(scale: followUps.scale!);
    }
    if (followUps.steps != null) {
      next = next.copyWith(steps: followUps.steps!);
    }
    if (followUps.noiseSchedule != null) {
      next = next.copyWith(noiseSchedule: followUps.noiseSchedule!);
    }
    if (followUps.varietyPlus != null) {
      next = next.copyWith(varietyPlus: followUps.varietyPlus!);
    }
    state = next;

    if (persist) {
      _storage.setDefaultModel(model);
      if (followUps.scale != null) {
        _storage.setDefaultScale(followUps.scale!);
      }
      if (followUps.steps != null) {
        _storage.setDefaultSteps(followUps.steps!);
      }
      if (followUps.noiseSchedule != null) {
        _storage.setLastNoiseSchedule(followUps.noiseSchedule!);
      }
      if (followUps.varietyPlus != null) {
        _storage.setLastVarietyPlus(followUps.varietyPlus!);
      }
    }
  }

  /// 更新尺寸
  void updateSize(int width, int height, {bool persist = true}) {
    state = state.copyWith(width: width, height: height);
    if (persist) {
      _storage.setDefaultWidth(width);
      _storage.setDefaultHeight(height);
    }
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
      // 测试期持久化的 custom 键迁移到正式 ID。
      model: ImageModels.migrateLegacyModel(storage.getDefaultModel()),
      sampler: storage.getDefaultSampler(),
      steps: storage.getDefaultSteps(),
      scale: storage.getDefaultScale(),
      width: storage.getDefaultWidth(),
      height: storage.getDefaultHeight(),
    );
    _scheduleGenerationStateSave(immediate: true);
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

  /// 更新局部重绘强度
  void updateInpaintStrength(double strength) {
    state = state.copyWith(inpaintStrength: strength);
  }

  /// 更新当前 infill 请求是否为扩图请求。
  void updateIsOutpaint(bool isOutpaint) {
    if (state.isOutpaint == isOutpaint) {
      return;
    }
    state = state.copyWith(isOutpaint: isOutpaint);
  }

  /// 清除 img2img 设置
  void clearImg2Img() {
    state = state.copyWith(
      action: ImageGenerationAction.generate,
      sourceImage: null,
      strength: 0.7,
      noise: 0.0,
      inpaintStrength: 1.0,
      isOutpaint: false,
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
      inpaintStrength: 1.0,
      isOutpaint: false,
    );
  }

  // ==================== V4 Vibe Transfer 参数 ====================

  /// 添加 V4 Vibe 参考
  /// 支持预编码 (.naiv4vibe, PNG 带元数据)
  /// 对于原始图片，会自动检查编码缓存避免重复 API 调用
  void addVibeReference(VibeReference vibe) {
    if (state.vibeReferencesV4.length >= 16) return; // V4 支持最多 16 张

    var vibeToAdd = vibe;

    // 检查是否是原始图片且需要编码
    if (vibe.canReencodeFromRawSource && vibe.vibeEncoding.isEmpty) {
      final cachedEncoding = _vibeReferences.getCached(
        vibe.rawImageData!,
        model: state.model,
        informationExtracted: vibe.infoExtracted,
      );
      if (cachedEncoding != null) {
        vibeToAdd = vibe.withEncodedVibe(cachedEncoding, model: state.model);
        _showCacheHitNotification(vibe.displayName);
      }
    }

    _applyVibeReferences([...state.vibeReferencesV4, vibeToAdd]);
  }

  String? getCachedVibeEncoding(
    Uint8List imageData, {
    String? model,
    required double informationExtracted,
  }) => _vibeReferences.getCached(
    imageData,
    model: model ?? state.model,
    informationExtracted: informationExtracted,
  );

  /// Vibe 列表的唯一写入口会建立缓存、补齐编码模型并执行 16 张上限。
  void _applyVibeReferences(
    List<VibeReference> vibes, {
    bool immediateSave = true,
  }) {
    state = state.copyWith(
      vibeReferencesV4: _vibeReferences.normalize(
        vibes,
        currentModel: state.model,
      ),
    );
    _scheduleGenerationStateSave(immediate: immediateSave);
  }

  /// 显示缓存命中通知
  void _showCacheHitNotification(String vibeName) {
    // 使用 AppLogger 记录，UI 层可以监听并显示 Toast
    AppLogger.i('Vibe 编码已从缓存加载: $vibeName', 'VibeCache');
  }

  /// 编码 Vibe 参考图（带缓存）
  ///
  /// [imageData] 原始图片数据
  /// [model] 模型名称
  /// [informationExtracted] 信息提取量
  /// [vibeName] Vibe 名称（用于日志）
  ///
  /// 返回编码后的 vibe 字符串，如果出错返回 null
  Future<String?> encodeVibeWithCache(
    Uint8List imageData, {
    required String model,
    double informationExtracted = 1.0,
    String? vibeName,
  }) async {
    final result = await _vibeReferences.encode(
      imageData,
      model: model,
      informationExtracted: informationExtracted,
      vibeName: vibeName,
    );
    if (result.isCacheHit) {
      _showCacheHitNotification(vibeName ?? 'unknown');
    }
    return result.encoding;
  }

  bool hasCachedVibeEncoding(
    Uint8List imageData, {
    required String model,
    double informationExtracted = 1.0,
  }) => _vibeReferences.hasCached(
    imageData,
    model: model,
    informationExtracted: informationExtracted,
  );

  /// 将编码存入缓存（供外部调用）
  void storeVibeEncodingInCache(
    Uint8List imageData,
    String encoding, {
    String? model,
    double informationExtracted = 0.7,
  }) {
    _vibeReferences.storeCached(
      imageData,
      encoding,
      model: model ?? state.model,
      informationExtracted: informationExtracted,
    );
  }

  /// 获取缓存大小
  int get vibeEncodingCacheSize => _vibeReferences.cacheSize;

  Future<List<VibeReference>> ensureVibeReferencesEncoded(
    List<VibeReference> vibes, {
    String? model,
    bool syncCurrentState = true,
  }) async {
    final encoded = await _vibeReferences.ensureEncoded(
      vibes,
      model: model ?? state.model,
    );
    if (_isDisposed) return encoded;
    if (!identical(encoded, vibes) &&
        syncCurrentState &&
        _vibeReferences.sameList(state.vibeReferencesV4, vibes)) {
      _applyVibeReferences(encoded);
    }
    return encoded;
  }

  /// 为库内“显式保存参数”准备持久化后的 Vibe 数据。
  ///
  /// 只有用户明确点击保存时才应调用这条链。若当前条目可重新编码，且：
  /// 1. 还没有编码，或
  /// 2. 信息提取发生变化
  /// 则会先生成新编码，再返回用于落文件的完整 Vibe 数据。
  Future<VibeReference?> prepareVibeForLibraryParamSave(
    VibeReference vibe, {
    required double strength,
    required double infoExtracted,
    String? model,
  }) {
    return _vibeReferences.prepareForLibrarySave(
      vibe,
      model: model ?? state.model,
      strength: strength,
      informationExtracted: infoExtracted,
    );
  }

  /// 清空编码缓存
  void clearVibeEncodingCache() {
    _vibeReferences.clearCache();
    AppLogger.i('Vibe 编码缓存已清空', 'VibeCache');
  }

  /// 批量添加 V4 Vibe 参考
  /// 如果 vibe 已存在，会移除旧的并添加新的（调整顺序）
  void addVibeReferences(List<VibeReference> vibes, {bool recordUsage = true}) {
    final merged = _vibeReferences.mergeReferences(
      state.vibeReferencesV4,
      vibes,
    );
    if (identical(merged, state.vibeReferencesV4)) return;
    _applyVibeReferences(merged);
    if (recordUsage) {
      for (final vibe in vibes) {
        _recordVibeUsage(vibe);
      }
    }
  }

  /// 移除 V4 Vibe 参考
  void removeVibeReference(int index) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    newList.removeAt(index);
    _applyVibeReferences(newList);
  }

  /// 更新 V4 Vibe 参考配置
  void updateVibeReference(
    int index, {
    double? strength,
    double? infoExtracted,
    String? vibeEncoding, // 新增：编码哈希
    bool? enabled,
  }) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    newList[index] = _vibeReferences.updateReference(
      newList[index],
      model: state.model,
      strength: strength,
      informationExtracted: infoExtracted,
      vibeEncoding: vibeEncoding,
      enabled: enabled,
    );
    _applyVibeReferences(newList, immediateSave: false);
  }

  /// 清除所有 V4 Vibe 参考
  void clearVibeReferences() {
    _applyVibeReferences(const []);
  }

  /// 设置 vibe references（替换现有）
  void setVibeReferences(List<VibeReference> vibes) {
    VibePerformanceDiagnostics.measureSync(
      'generation.setVibeReferences',
      () {
        // 限制最多 16 个
        _applyVibeReferences(vibes.take(16).toList());
      },
      details: {
        'inputVibes': vibes.length,
        'existingVibes': state.vibeReferencesV4.length,
      },
    );
  }

  /// 设置 Vibe 强度标准化开关
  void setNormalizeVibeStrength(bool value) {
    state = state.copyWith(normalizeVibeStrength: value);
    _scheduleGenerationStateSave(immediate: true);
  }

  // ==================== Vibe Library 操作 ====================

  /// 保存所有当前 Vibes 到库
  ///
  /// [name] 库条目名称
  /// 返回创建的库条目 ID，失败返回 null
  Future<String?> saveCurrentVibesToLibrary(String name) {
    return _vibeReferences.saveReferencesToLibrary(
      state.vibeReferencesV4,
      model: state.model,
      name: name,
    );
  }

  /// 从库中添加 Vibe
  ///
  /// [entryId] 库条目 ID
  /// 返回是否成功添加
  Future<bool> addVibeFromLibrary(String entryId) async {
    if (state.vibeReferencesV4.length >= 16) return false;
    final vibe = await _vibeReferences.useLibraryEntry(entryId);
    if (vibe == null || _isDisposed) return false;
    addVibeReference(vibe);
    state = state.copyWith();
    return true;
  }

  /// 使用库中的 Vibe 更新指定位置的 Vibe
  ///
  /// [index] 当前 vibes 列表中的索引
  /// [entryId] 库条目 ID
  /// 返回是否成功更新
  Future<bool> updateVibeFromLibrary(int index, String entryId) async {
    if (index < 0 || index >= state.vibeReferencesV4.length) return false;
    final vibe = await _vibeReferences.useLibraryEntry(entryId);
    if (vibe == null || _isDisposed || index >= state.vibeReferencesV4.length) {
      return false;
    }
    final references = [...state.vibeReferencesV4];
    references[index] = vibe;
    _applyVibeReferences(references);
    state = state.copyWith();
    return true;
  }

  // ==================== Precise Reference 参数 (V4+ 模型) ====================

  /// 添加 Precise Reference
  void addPreciseReference(
    Uint8List image, {
    required PreciseRefType type,
    double strength = 1.0,
    double fidelity = 1.0,
    bool isNormalizedPng = false,
  }) {
    if (isNormalizedPng) {
      NAIApiUtils.markNormalizedPreciseReferencePng(image);
    }
    state = state.copyWith(
      preciseReferences: [
        ...state.preciseReferences,
        PreciseReference(
          image: image,
          type: type,
          strength: strength,
          fidelity: fidelity,
        ),
      ],
    );
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 添加原始图片形式的 Precise Reference，并在后台完成 Director PNG 规范化。
  ///
  /// 原图会先进入状态，保证用户快速点击生成时请求构建器仍能读取到参考图；
  /// 规范化完成后再替换为可直接提交的 PNG，避免后续生成重复处理。
  Future<void> addPreciseReferenceFromImage(
    Uint8List image, {
    required PreciseRefType type,
    double strength = 1.0,
    double fidelity = 1.0,
  }) async {
    final index = state.preciseReferences.length;
    addPreciseReference(
      image,
      type: type,
      strength: strength,
      fidelity: fidelity,
    );

    final normalization = await _vibeReferences.normalizePrecisePng(image);
    final normalizedImage = normalization.image;
    if (normalizedImage == null ||
        _isDisposed ||
        index >= state.preciseReferences.length) {
      return;
    }

    final current = state.preciseReferences[index];
    if (!identical(current.image, image)) return;

    final newList = [...state.preciseReferences];
    newList[index] = current.copyWith(image: normalizedImage);
    state = state.copyWith(preciseReferences: newList);
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 移除 Precise Reference
  void removePreciseReference(int index) {
    if (index < 0 || index >= state.preciseReferences.length) return;
    final newList = [...state.preciseReferences];
    newList.removeAt(index);
    state = state.copyWith(preciseReferences: newList);
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 更新 Precise Reference 配置
  void updatePreciseReference(
    int index, {
    PreciseRefType? type,
    double? strength,
    double? fidelity,
    bool? enabled,
  }) {
    if (index < 0 || index >= state.preciseReferences.length) return;
    final newList = [...state.preciseReferences];
    final current = newList[index];
    newList[index] = current.copyWith(
      type: type ?? current.type,
      strength: strength ?? current.strength,
      fidelity: fidelity ?? current.fidelity,
      enabled: enabled ?? current.enabled,
    );
    state = state.copyWith(preciseReferences: newList);
    _scheduleGenerationStateSave();
  }

  /// 更新 Precise Reference 类型
  void updatePreciseReferenceType(int index, PreciseRefType type) {
    if (index < 0 || index >= state.preciseReferences.length) return;
    final newList = [...state.preciseReferences];
    final current = newList[index];
    newList[index] = current.copyWith(type: type);
    state = state.copyWith(preciseReferences: newList);
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 清除所有 Precise Reference
  void clearPreciseReferences() {
    state = state.copyWith(preciseReferences: []);
    _scheduleGenerationStateSave(immediate: true);
  }

  // ==================== 状态持久化 ====================

  /// 保存当前 Vibe 和精准参考状态。
  Future<void> saveGenerationState() =>
      _persistence.save(_generationStateSnapshot);

  /// 恢复调用共享 service 的 single-flight Future；迟到结果不会写入已销毁状态。
  Future<void> restoreGenerationState() {
    if (_hasAppliedGenerationStateRestore) return Future<void>.value();
    final active = _generationStateRestoreInFlight;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _restoreGenerationState().whenComplete(() {
      if (identical(_generationStateRestoreInFlight, operation)) {
        _generationStateRestoreInFlight = null;
      }
    });
    _generationStateRestoreInFlight = operation;
    return operation;
  }

  Future<void> _restoreGenerationState() async {
    final restored = await _persistence.restore();
    if (_isDisposed) return;
    _hasAppliedGenerationStateRestore = restored.isTerminal;
    if (!restored.shouldApply) return;

    state = state.copyWith(
      vibeReferencesV4: _vibeReferences.normalize(
        restored.vibeReferences,
        currentModel: state.model,
      ),
      preciseReferences: restored.preciseReferences,
      normalizeVibeStrength: restored.normalizeVibeStrength,
    );
    if (restored.shouldRewrite) unawaited(saveGenerationState());
  }

  // ==================== 多角色参数 (V4 模型) ====================

  /// 添加角色
  void addCharacter(CharacterPrompt character) {
    state = state.copyWith(characters: [...state.characters, character]);
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
    final presetType = UcPresets.getPresetTypeFromInt(ucPreset);
    state = state.copyWith(ucPreset: UcPresets.toApiValue(presetType));
    ref.read(ucPresetNotifierProvider.notifier).setPresetType(presetType);
  }

  /// 更新质量标签开关
  void updateQualityToggle(bool qualityToggle) {
    state = state.copyWith(qualityToggle: qualityToggle);
    final qualityPreset = ref.read(qualityPresetNotifierProvider.notifier);
    if (qualityToggle) {
      qualityPreset.setNaiDefault();
    } else {
      qualityPreset.setNone();
    }
  }

  /// 更新多样性增强 (V4+)
  void updateVarietyPlus(bool varietyPlus) {
    state = state.copyWith(varietyPlus: varietyPlus);
    _storage.setLastVarietyPlus(varietyPlus);
  }

  /// 更新 Decrisp (V3 模型)
  void updateDecrisp(bool decrisp) {
    state = state.copyWith(decrisp: decrisp);
  }

  /// 更新官方质量词档位 (standard/light)
  ///
  /// 持久化由质量预设 Provider 负责，这里只同步请求构造使用的状态。
  void updateQualityTier(String qualityTier) {
    if (state.qualityTier == qualityTier) {
      return;
    }
    state = state.copyWith(qualityTier: qualityTier);
  }

  /// 更新透明背景开关 (仅 V5)
  ///
  /// 不支持的模型只是请求里不带这些参数，开关值照常保留，
  /// 用户在 V4.5 与 V5 之间来回切换时不会丢掉选择。
  void updateTransparentBackground(bool transparentBackground) {
    state = state.copyWith(transparentBackground: transparentBackground);
    _storage.setLastTransparentBackground(transparentBackground);
  }

  /// 更新透明图像 Alpha 模式（true=Straight，false=Premultiplied）。
  void updateStraightAlpha(bool straightAlpha) {
    state = state.copyWith(straightAlpha: straightAlpha);
    _storage.setImageStraightAlpha(straightAlpha);
  }

  /// 更新端到端 ×2 放大开关 (仅 V5)
  void updateE2eUpscale(bool e2eUpscale) {
    state = state.copyWith(e2eUpscale: e2eUpscale);
    _storage.setLastE2eUpscale(e2eUpscale);
  }

  /// 更新增强 max 档 (仅 V5)
  ///
  /// 由增强工作流按当前档位驱动，属于单次请求状态，不落盘。
  void updateUpscaledEnhance(bool upscaledEnhance) {
    if (state.upscaledEnhance == upscaledEnhance) {
      return;
    }
    state = state.copyWith(upscaledEnhance: upscaledEnhance);
  }

  /// 标记当前 img2img 请求来自增强面板
  ///
  /// 决定是否自动补 `-2::upscaled, blurry::`，同样只属于单次请求。
  void updateIsEnhanceRequest(bool isEnhanceRequest) {
    if (state.isEnhanceRequest == isEnhanceRequest) {
      return;
    }
    state = state.copyWith(isEnhanceRequest: isEnhanceRequest);
  }

  /// 更新使用坐标模式 (V4+ 多角色)
  void updateUseCoords(bool useCoords) {
    state = state.copyWith(useCoords: useCoords);
  }

  /// 更新添加原始图像
  void updateAddOriginalImage(bool addOriginalImage) {
    state = state.copyWith(addOriginalImage: addOriginalImage);
  }

  // ==================== 面板展开状态管理 ====================

  /// 加载面板展开状态
  Future<void> loadPanelStates() async {
    final expanded = await _persistence.loadAdvancedOptionsExpanded();
    if (expanded != null && !_isDisposed) {
      state = state.copyWith(advancedOptionsExpanded: expanded);
    }
  }

  /// 保存面板展开状态
  Future<void> savePanelStates() =>
      _persistence.saveAdvancedOptionsExpanded(state.advancedOptionsExpanded);

  /// 切换高级选项面板展开状态
  Future<void> toggleAdvancedOptionsExpanded() async {
    final newState = !state.advancedOptionsExpanded;
    state = state.copyWith(advancedOptionsExpanded: newState);
    await savePanelStates();
  }

  /// 设置高级选项面板展开状态
  Future<void> setAdvancedOptionsExpanded(bool expanded) async {
    state = state.copyWith(advancedOptionsExpanded: expanded);
    await savePanelStates();
  }
}
