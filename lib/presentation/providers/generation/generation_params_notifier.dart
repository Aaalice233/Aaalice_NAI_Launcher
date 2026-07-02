import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
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
import '../quality_preset_provider.dart';
import '../uc_preset_provider.dart';

part 'generation_params_notifier.g.dart';

/// 图像生成参数 Notifier
@Riverpod(keepAlive: true)
class GenerationParamsNotifier extends _$GenerationParamsNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  /// Vibe 编码缓存 - 内存缓存，避免重复 API 调用
  /// Key: 图片数据的 SHA256 哈希值
  /// Value: 编码后的 vibe 字符串
  final Map<String, String> _vibeEncodingCache = {};

  /// 最近使用的 Vibes (最多 20 个)
  List<VibeLibraryEntry> _recentVibes = [];

  Timer? _generationStateSaveDebounceTimer;
  Future<void>? _generationStateSaveInFlight;
  bool _hasQueuedGenerationStateSave = false;
  bool _isRestoringGenerationState = false;
  bool _hasRestoredGenerationState = false;
  bool _isDisposed = false;

  /// 获取最近使用的 Vibes (最多 5 个用于显示)
  List<VibeLibraryEntry> get recentVibes => _recentVibes.take(5).toList();

  void _scheduleGenerationStateSave({bool immediate = false}) {
    if (_isRestoringGenerationState) {
      return;
    }

    if (immediate) {
      _generationStateSaveDebounceTimer?.cancel();
      unawaited(saveGenerationState());
      return;
    }

    _generationStateSaveDebounceTimer?.cancel();
    _generationStateSaveDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      () {
        unawaited(saveGenerationState());
      },
    );
  }

  /// 加载最近使用的 Vibes
  Future<void> loadRecentVibes() async {
    final span = VibePerformanceDiagnostics.start('generation.loadRecentVibes');
    var entryCount = 0;
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final entries = await storageService.getRecentDisplayEntries(limit: 20);
      entryCount = entries.length;
      _recentVibes = entries;
      // 通知监听器更新
      state = state.copyWith();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load recent vibes', e, stackTrace);
    } finally {
      span.finish(details: {'entries': entryCount});
    }
  }

  /// 记录 Vibe 使用并更新最近列表
  Future<void> _recordVibeUsage(VibeReference vibe) async {
    final span = VibePerformanceDiagnostics.start(
      'generation.recordVibeUsage',
      details: {
        'hasEncoding': vibe.vibeEncoding.isNotEmpty,
        'hasThumbnail': vibe.thumbnail?.isNotEmpty == true,
        'hasRawImage': vibe.rawImageData?.isNotEmpty == true,
      },
    );
    var matchedExisting = false;
    var createdEntry = false;
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final existingEntry = await storageService.findMatchingEntry(vibe);

      if (existingEntry != null) {
        matchedExisting = true;
        // 更新现有条目的使用时间
        await storageService.incrementUsedCount(existingEntry.id);
      } else if (vibe.vibeEncoding.isNotEmpty) {
        // 只有预编码的 vibe 才创建新条目
        final newEntry = VibeLibraryEntry.fromVibeReference(
          name: vibe.displayName,
          vibeData: vibe,
        );
        await storageService.saveEntry(newEntry);
        await storageService.incrementUsedCount(newEntry.id);
        createdEntry = true;
      }

      // 重新加载最近列表
      await loadRecentVibes();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to record vibe usage', e, stackTrace);
    } finally {
      span.finish(
        details: {
          'matchedExisting': matchedExisting,
          'createdEntry': createdEntry,
        },
      );
    }
  }

  @override
  ImageParams build() {
    ref.onDispose(() {
      _isDisposed = true;
      _generationStateSaveDebounceTimer?.cancel();
    });

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
      varietyPlus: storage.getLastVarietyPlus(),
      // 从存储加载种子锁定状态
      seed: storage.getSeedLocked() && storage.getLockedSeedValue() != null
          ? storage.getLockedSeedValue()!
          : -1,
    );
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
    // 使用 Future.microtask 延迟更新，避免在 widget tree 构建期间修改 provider
    Future.microtask(() {
      state = state.copyWith(prompt: prompt);
      _storage.setLastPrompt(prompt);
    });
  }

  /// 更新负向提示词
  void updateNegativePrompt(String negativePrompt) {
    // 使用 Future.microtask 延迟更新，避免在 widget tree 构建期间修改 provider
    Future.microtask(() {
      state = state.copyWith(negativePrompt: negativePrompt);
      _storage.setLastNegativePrompt(negativePrompt);
    });
  }

  /// 更新模型
  void updateModel(String model, {bool persist = true}) {
    state = state.copyWith(model: model);
    if (persist) {
      _storage.setDefaultModel(model);
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
      model: storage.getDefaultModel(),
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
      final cacheKey = _buildVibeEncodingCacheKey(
        vibe.rawImageData!,
        model: state.model,
        informationExtracted: vibe.infoExtracted,
      );

      // 检查缓存
      if (_vibeEncodingCache.containsKey(cacheKey)) {
        // 缓存命中 - 使用缓存的编码
        final cachedEncoding = _vibeEncodingCache[cacheKey]!;
        AppLogger.i('Vibe 编码缓存命中: ${vibe.displayName}', 'VibeCache');

        // 更新 vibe 使用缓存的编码
        vibeToAdd = vibe.withEncodedVibe(cachedEncoding);

        // 显示缓存命中通知
        _showCacheHitNotification(vibe.displayName);
      }
    }

    _primeVibeEncodingCache(vibeToAdd);

    state = state.copyWith(
      vibeReferencesV4: [...state.vibeReferencesV4, vibeToAdd],
    );
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 计算图片数据的 SHA256 哈希值（用于缓存键）
  String _calculateImageHash(Uint8List imageData) {
    final bytes = sha256.convert(imageData).bytes;
    return base64Encode(bytes);
  }

  String _buildVibeEncodingCacheKey(
    Uint8List imageData, {
    required String model,
    required double informationExtracted,
  }) {
    final imageHash = _calculateImageHash(imageData);
    final sanitizedInfoExtracted = VibeReference.sanitizeInfoExtracted(
      informationExtracted,
    );
    return '$imageHash|$model|$sanitizedInfoExtracted';
  }

  String? getCachedVibeEncoding(
    Uint8List imageData, {
    String? model,
    required double informationExtracted,
  }) {
    final cacheKey = _buildVibeEncodingCacheKey(
      imageData,
      model: model ?? state.model,
      informationExtracted: informationExtracted,
    );
    return _vibeEncodingCache[cacheKey];
  }

  void _primeVibeEncodingCache(VibeReference vibe, {String? model}) {
    final rawImageData = vibe.rawImageData;
    if (rawImageData == null ||
        rawImageData.isEmpty ||
        vibe.vibeEncoding.isEmpty) {
      return;
    }

    final cacheKey = _buildVibeEncodingCacheKey(
      rawImageData,
      model: model ?? state.model,
      informationExtracted: vibe.infoExtracted,
    );
    _vibeEncodingCache.putIfAbsent(cacheKey, () => vibe.vibeEncoding);
  }

  bool _isSameVibeSource(VibeReference left, VibeReference right) {
    if (left.vibeEncoding.isNotEmpty && right.vibeEncoding.isNotEmpty) {
      return left.vibeEncoding == right.vibeEncoding;
    }

    if (left.rawImageData != null && right.rawImageData != null) {
      return _calculateImageHash(left.rawImageData!) ==
          _calculateImageHash(right.rawImageData!);
    }

    return left.displayName == right.displayName &&
        left.bundleSource == right.bundleSource;
  }

  bool _isSameVibeList(List<VibeReference> left, List<VibeReference> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!_isSameVibeSource(left[i], right[i])) {
        return false;
      }
    }
    return true;
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
    final cacheKey = _buildVibeEncodingCacheKey(
      imageData,
      model: model,
      informationExtracted: informationExtracted,
    );

    // 检查缓存
    if (_vibeEncodingCache.containsKey(cacheKey)) {
      AppLogger.i('Vibe 编码缓存命中: ${vibeName ?? 'unknown'}', 'VibeCache');
      _showCacheHitNotification(vibeName ?? 'unknown');
      return _vibeEncodingCache[cacheKey];
    }

    // 缓存未命中，调用 API
    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final encoding = await apiService.encodeVibe(
        imageData,
        model: model,
        informationExtracted: informationExtracted,
      );

      // 存入缓存
      _vibeEncodingCache[cacheKey] = encoding;
      AppLogger.i('Vibe 编码已缓存: ${vibeName ?? 'unknown'}', 'VibeCache');

      return encoding;
    } catch (e, stack) {
      AppLogger.e('Vibe 编码失败: ${vibeName ?? 'unknown'}', e, stack, 'VibeCache');
      return null;
    }
  }

  /// 将编码存入缓存（供外部调用）
  ///
  /// [imageData] 原始图片数据
  /// [encoding] 编码后的 vibe 字符串
  void storeVibeEncodingInCache(
    Uint8List imageData,
    String encoding, {
    String? model,
    double informationExtracted = 0.7,
  }) {
    final cacheKey = _buildVibeEncodingCacheKey(
      imageData,
      model: model ?? state.model,
      informationExtracted: informationExtracted,
    );
    _vibeEncodingCache[cacheKey] = encoding;
    AppLogger.d(
      'Vibe 编码已手动存入缓存，当前缓存大小: ${_vibeEncodingCache.length}',
      'VibeCache',
    );
  }

  /// 获取缓存大小
  int get vibeEncodingCacheSize => _vibeEncodingCache.length;

  Future<List<VibeReference>> ensureVibeReferencesEncoded(
    List<VibeReference> vibes, {
    String? model,
    bool syncCurrentState = true,
  }) async {
    if (vibes.isEmpty) {
      return vibes;
    }

    final resolvedModel = model ?? state.model;
    var changed = false;
    final encodedVibes = <VibeReference>[];

    for (final vibe in vibes) {
      if (!vibe.canReencodeFromRawSource || vibe.vibeEncoding.isNotEmpty) {
        encodedVibes.add(vibe);
        continue;
      }

      final rawImageData = vibe.rawImageData;
      if (rawImageData == null) {
        encodedVibes.add(vibe);
        continue;
      }

      final cachedEncoding = getCachedVibeEncoding(
        rawImageData,
        model: resolvedModel,
        informationExtracted: vibe.infoExtracted,
      );
      if (cachedEncoding != null && cachedEncoding.isNotEmpty) {
        encodedVibes.add(vibe.withEncodedVibe(cachedEncoding));
        changed = true;
        continue;
      }

      final encoding = await encodeVibeWithCache(
        rawImageData,
        model: resolvedModel,
        informationExtracted: vibe.infoExtracted,
        vibeName: vibe.displayName,
      );
      if (encoding != null && encoding.isNotEmpty) {
        encodedVibes.add(vibe.withEncodedVibe(encoding));
        changed = true;
      } else {
        encodedVibes.add(vibe);
      }
    }

    if (changed &&
        syncCurrentState &&
        _isSameVibeList(state.vibeReferencesV4, vibes)) {
      state = state.copyWith(vibeReferencesV4: encodedVibes);
      _scheduleGenerationStateSave(immediate: true);
    }

    return changed ? encodedVibes : vibes;
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
  }) async {
    final resolvedModel = model ?? state.model;
    final nextStrength = VibeReference.sanitizeStrength(strength);
    final nextInfoExtracted = VibeReference.sanitizeInfoExtracted(
      infoExtracted,
    );
    final nextVibe = vibe.copyWith(
      strength: nextStrength,
      infoExtracted: nextInfoExtracted,
    );

    final shouldEncode =
        nextVibe.canReencodeFromRawSource &&
        (nextVibe.vibeEncoding.isEmpty ||
            nextInfoExtracted != vibe.infoExtracted);
    if (!shouldEncode) {
      return nextVibe.normalizedForLibraryStorage();
    }

    final rawImageData = nextVibe.rawImageData;
    if (rawImageData == null || rawImageData.isEmpty) {
      return nextVibe;
    }

    final cachedEncoding = getCachedVibeEncoding(
      rawImageData,
      model: resolvedModel,
      informationExtracted: nextInfoExtracted,
    );
    final encoding =
        cachedEncoding ??
        await encodeVibeWithCache(
          rawImageData,
          model: resolvedModel,
          informationExtracted: nextInfoExtracted,
          vibeName: nextVibe.displayName,
        );
    if (encoding == null || encoding.isEmpty) {
      return null;
    }

    return nextVibe.withEncodedVibe(encoding);
  }

  /// 清空编码缓存
  void clearVibeEncodingCache() {
    _vibeEncodingCache.clear();
    AppLogger.i('Vibe 编码缓存已清空', 'VibeCache');
  }

  /// 批量添加 V4 Vibe 参考
  /// 如果 vibe 已存在，会移除旧的并添加新的（调整顺序）
  void addVibeReferences(List<VibeReference> vibes, {bool recordUsage = true}) {
    final span = VibePerformanceDiagnostics.start(
      'generation.addVibeReferences',
      details: {
        'inputVibes': vibes.length,
        'recordUsage': recordUsage,
        'existingVibes': state.vibeReferencesV4.length,
      },
    );
    var toAddCount = 0;
    var toReorderCount = 0;
    var addedCount = 0;
    var finalCount = state.vibeReferencesV4.length;
    try {
      // 分批处理：先找出已存在的和新的
      final toReorder = <VibeReference>[];
      final toAdd = <VibeReference>[];

      for (final vibe in vibes) {
        final existingIndex = _findVibeIndex(state.vibeReferencesV4, vibe);
        if (existingIndex >= 0) {
          toReorder.add(vibe);
        } else {
          toAdd.add(vibe);
        }
      }
      toAddCount = toAdd.length;
      toReorderCount = toReorder.length;

      // 如果没有需要处理的，直接返回
      if (toReorder.isEmpty && toAdd.isEmpty) return;

      // 构建新列表：移除已存在的，添加所有新的（调整顺序）
      var newVibes = [...state.vibeReferencesV4];

      // 先移除需要调整顺序的
      for (final vibe in toReorder) {
        final index = _findVibeIndex(newVibes, vibe);
        if (index >= 0) {
          newVibes = [
            ...newVibes.sublist(0, index),
            ...newVibes.sublist(index + 1),
          ];
        }
      }

      // 添加所有新的（先添加 toAdd，再添加 toReorder 到末尾）
      final availableSlots = 16 - newVibes.length;
      final canAdd = toAdd.take(availableSlots).toList();
      addedCount = canAdd.length + toReorder.length;
      newVibes = [...newVibes, ...canAdd, ...toReorder];

      // 限制最多 16 个（如果超过，保留后 16 个）
      if (newVibes.length > 16) {
        newVibes = newVibes.sublist(newVibes.length - 16);
      }

      for (final vibe in newVibes) {
        _primeVibeEncodingCache(vibe);
      }

      // 更新状态
      state = state.copyWith(vibeReferencesV4: newVibes);
      finalCount = newVibes.length;
      _scheduleGenerationStateSave(immediate: true);

      if (recordUsage) {
        // 记录使用
        for (final vibe in [...canAdd, ...toReorder]) {
          _recordVibeUsage(vibe);
        }
      }
    } finally {
      span.finish(
        details: {
          'toAdd': toAddCount,
          'toReorder': toReorderCount,
          'added': addedCount,
          'finalVibes': finalCount,
        },
      );
    }
  }

  /// 在列表中查找相同的 vibe 的索引
  /// 返回索引，如果没有找到返回 -1
  int _findVibeIndex(List<VibeReference> vibes, VibeReference target) {
    for (var i = 0; i < vibes.length; i++) {
      final vibe = vibes[i];
      // 如果 vibeEncoding 不为空，比较编码
      if (target.vibeEncoding.isNotEmpty && vibe.vibeEncoding.isNotEmpty) {
        if (vibe.vibeEncoding == target.vibeEncoding) {
          return i;
        }
      }
      // 对于原始图片，比较图片哈希
      else if (target.rawImageData != null && vibe.rawImageData != null) {
        if (_calculateImageHash(vibe.rawImageData!) ==
            _calculateImageHash(target.rawImageData!)) {
          return i;
        }
      }
      // 其他情况比较 displayName
      else if (vibe.displayName == target.displayName) {
        return i;
      }
    }
    return -1;
  }

  /// 移除 V4 Vibe 参考
  void removeVibeReference(int index) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    newList.removeAt(index);
    state = state.copyWith(vibeReferencesV4: newList);
    _scheduleGenerationStateSave(immediate: true);
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
    final current = newList[index];
    final nextStrength = strength != null
        ? VibeReference.sanitizeStrength(strength)
        : current.strength;
    final nextInfoExtracted = infoExtracted != null
        ? VibeReference.sanitizeInfoExtracted(infoExtracted)
        : current.infoExtracted;
    final infoChanged = nextInfoExtracted != current.infoExtracted;
    String nextEncoding;
    if (vibeEncoding != null) {
      nextEncoding = vibeEncoding;
    } else if (infoChanged && current.canReencodeFromRawSource) {
      final rawImageData = current.rawImageData;
      final cachedEncoding = rawImageData == null
          ? null
          : getCachedVibeEncoding(
              rawImageData,
              informationExtracted: nextInfoExtracted,
            );
      nextEncoding = cachedEncoding ?? '';
    } else {
      nextEncoding = current.vibeEncoding;
    }
    var nextVibe = current.copyWith(
      strength: nextStrength,
      infoExtracted: nextInfoExtracted,
      vibeEncoding: nextEncoding,
      enabled: enabled ?? current.enabled,
    );
    if (nextEncoding.isNotEmpty) {
      nextVibe = nextVibe.normalizedForLibraryStorage();
    }
    newList[index] = nextVibe;
    state = state.copyWith(vibeReferencesV4: newList);
    _scheduleGenerationStateSave();
  }

  /// 清除所有 V4 Vibe 参考
  void clearVibeReferences() {
    state = state.copyWith(vibeReferencesV4: []);
    _scheduleGenerationStateSave(immediate: true);
  }

  /// 设置 vibe references（替换现有）
  void setVibeReferences(List<VibeReference> vibes) {
    VibePerformanceDiagnostics.measureSync(
      'generation.setVibeReferences',
      () {
        // 限制最多 16 个
        final limitedVibes = vibes.take(16).toList();
        for (final vibe in limitedVibes) {
          _primeVibeEncodingCache(vibe);
        }
        state = state.copyWith(vibeReferencesV4: limitedVibes);
        _scheduleGenerationStateSave(immediate: true);
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
  Future<String?> saveCurrentVibesToLibrary(String name) async {
    if (state.vibeReferencesV4.isEmpty) return null;

    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);

      // 取第一个 vibe 作为代表（库条目对应单个 vibe）
      // 如果要保存多个 vibes，为每个 vibe 创建单独的条目
      final savedIds = <String>[];

      for (final vibe in state.vibeReferencesV4) {
        final preparedVibe = await prepareVibeForLibraryParamSave(
          vibe,
          strength: vibe.strength,
          infoExtracted: vibe.infoExtracted,
          model: state.model,
        );
        if (preparedVibe == null) {
          return null;
        }

        final entry = VibeLibraryEntry.fromVibeReference(
          name: state.vibeReferencesV4.length == 1
              ? name
              : '$name (${vibe.displayName})',
          vibeData: preparedVibe.normalizedForLibraryStorage(),
        );
        await storageService.saveEntry(entry);
        savedIds.add(entry.id);
      }

      AppLogger.i(
        'Saved ${savedIds.length} vibes to library: $name',
        'VibeLibrary',
      );

      // 重新加载最近使用的 vibes
      await loadRecentVibes();

      // 返回第一个条目的 ID
      return savedIds.isNotEmpty ? savedIds.first : null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save vibes to library', e, stackTrace);
      return null;
    }
  }

  /// 从库中添加 Vibe
  ///
  /// [entryId] 库条目 ID
  /// 返回是否成功添加
  Future<bool> addVibeFromLibrary(String entryId) async {
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final entry = await storageService.getEntry(entryId);

      if (entry == null) {
        AppLogger.w('Vibe library entry not found: $entryId', 'VibeLibrary');
        return false;
      }

      // 检查是否已达到最大数量限制
      if (state.vibeReferencesV4.length >= 16) {
        AppLogger.w('Maximum vibe references reached (16)', 'VibeLibrary');
        return false;
      }

      // 转换为 VibeReference 并添加
      final vibe = entry.toVibeReference();
      addVibeReference(vibe);

      // 记录使用
      await storageService.incrementUsedCount(entryId);
      await loadRecentVibes();

      AppLogger.i(
        'Added vibe from library: ${entry.displayName}',
        'VibeLibrary',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to add vibe from library', e, stackTrace);
      return false;
    }
  }

  /// 使用库中的 Vibe 更新指定位置的 Vibe
  ///
  /// [index] 当前 vibes 列表中的索引
  /// [entryId] 库条目 ID
  /// 返回是否成功更新
  Future<bool> updateVibeFromLibrary(int index, String entryId) async {
    try {
      if (index < 0 || index >= state.vibeReferencesV4.length) {
        AppLogger.w('Invalid vibe index: $index', 'VibeLibrary');
        return false;
      }

      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final entry = await storageService.getEntry(entryId);

      if (entry == null) {
        AppLogger.w('Vibe library entry not found: $entryId', 'VibeLibrary');
        return false;
      }

      // 转换为 VibeReference
      final vibe = entry.toVibeReference();

      // 更新指定位置的 vibe
      final newList = [...state.vibeReferencesV4];
      newList[index] = vibe;
      state = state.copyWith(vibeReferencesV4: newList);
      _scheduleGenerationStateSave(immediate: true);

      // 记录使用
      await storageService.incrementUsedCount(entryId);
      await loadRecentVibes();

      AppLogger.i(
        'Updated vibe at index $index from library: ${entry.displayName}',
        'VibeLibrary',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update vibe from library', e, stackTrace);
      return false;
    }
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

    final Uint8List normalizedImage;
    try {
      normalizedImage = await NAIApiUtils.ensurePngFormatAsync(image);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to normalize precise reference image',
        e,
        stackTrace,
        'GenerationParams',
      );
      return;
    }
    if (_isDisposed || index >= state.preciseReferences.length) {
      return;
    }

    final current = state.preciseReferences[index];
    if (!identical(current.image, image)) {
      return;
    }

    final newList = [...state.preciseReferences];
    NAIApiUtils.markNormalizedPreciseReferencePng(normalizedImage);
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

  /// 保存当前 Vibe 和精准参考状态
  Future<void> saveGenerationState() {
    if (_isRestoringGenerationState || _isDisposed) {
      return Future<void>.value();
    }

    final activeSave = _generationStateSaveInFlight;
    if (activeSave != null) {
      _hasQueuedGenerationStateSave = true;
      return VibePerformanceDiagnostics.measure(
        'generation.awaitActiveStateSave',
        () async => activeSave,
        details: {
          'vibes': state.vibeReferencesV4.length,
          'preciseRefs': state.preciseReferences.length,
        },
      );
    }

    final saveOperation = _runGenerationStateSaveLoop().whenComplete(() {
      _generationStateSaveInFlight = null;
    });
    _generationStateSaveInFlight = saveOperation;
    return saveOperation;
  }

  Future<void> _runGenerationStateSaveLoop() async {
    final span = VibePerformanceDiagnostics.start(
      'generation.runStateSaveLoop',
      details: {
        'vibes': state.vibeReferencesV4.length,
        'preciseRefs': state.preciseReferences.length,
      },
    );
    var iterations = 0;
    try {
      do {
        iterations++;
        await Future<void>.delayed(Duration.zero);
        _hasQueuedGenerationStateSave = false;
        if (_isRestoringGenerationState || _isDisposed) {
          return;
        }

        await _saveGenerationStateSnapshot();
      } while (_hasQueuedGenerationStateSave);
    } finally {
      span.finish(
        details: {
          'iterations': iterations,
          'queuedAgain': _hasQueuedGenerationStateSave,
        },
      );
    }
  }

  Future<void> _saveGenerationStateSnapshot() async {
    if (_isDisposed) {
      return;
    }

    final span = VibePerformanceDiagnostics.start(
      'generation.saveStateSnapshot',
      details: {
        'vibes': state.vibeReferencesV4.length,
        'preciseRefs': state.preciseReferences.length,
      },
    );
    var jsonChars = 0;
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final saveInput = _buildGenerationStateSaveInput(
        vibeReferences: state.vibeReferencesV4,
        preciseReferences: state.preciseReferences,
        normalizeVibeStrength: state.normalizeVibeStrength,
      );
      final stateJson = await Isolate.run(
        () => _encodeGenerationStateJson(saveInput),
      );
      jsonChars = stateJson.length;

      await storageService.saveGenerationStateJson(stateJson);

      AppLogger.d('Generation state saved', 'GenerationParams');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save generation state', e, stackTrace);
    } finally {
      span.finish(details: {'jsonChars': jsonChars});
    }
  }

  /// 恢复保存的 Vibe 和精准参考状态
  Future<void> restoreGenerationState() async {
    if (_hasRestoredGenerationState || _isRestoringGenerationState) {
      return;
    }

    final span = VibePerformanceDiagnostics.start('generation.restoreState');
    _isRestoringGenerationState = true;
    var shouldRewriteGenerationState = false;
    var jsonChars = 0;
    var restoredVibeCount = 0;
    var restoredPreciseRefCount = 0;

    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final stateJson = await storageService.loadGenerationStateJson();

      if (stateJson == null || stateJson.isEmpty) {
        _hasRestoredGenerationState = true;
        AppLogger.d('No saved generation state found', 'GenerationParams');
        return;
      }
      jsonChars = stateJson.length;

      final stateData = await Isolate.run(
        () => _decodeGenerationStateJson(stateJson),
      );

      final restoredVibes = <VibeReference>[];
      final vibeRefsData = stateData['vibeReferences'] as List? ?? const [];
      for (var i = 0; i < vibeRefsData.length; i++) {
        final raw = vibeRefsData[i];
        if (raw is! Map) {
          continue;
        }

        final refData = Map<String, dynamic>.from(raw);
        final sourceTypeName = refData['sourceType'] as String?;
        final sourceType = VibeSourceType.values.firstWhere(
          (item) => item.name == sourceTypeName,
          orElse: () => VibeSourceType.rawImage,
        );
        final thumbnailBytes = refData['thumbnail'] as Uint8List?;
        final rawImageBytes = refData['rawImageData'] as Uint8List?;

        restoredVibes.add(
          VibeReference(
            displayName: refData['displayName'] as String? ?? 'Vibe ${i + 1}',
            vibeEncoding: refData['vibeEncoding'] as String? ?? '',
            thumbnail: thumbnailBytes ?? rawImageBytes,
            rawImageData: rawImageBytes,
            strength: (refData['strength'] as num?)?.toDouble() ?? 0.6,
            infoExtracted:
                (refData['infoExtracted'] as num?)?.toDouble() ?? 0.7,
            sourceType: sourceType,
            enabled: refData['enabled'] as bool? ?? true,
            bundleSource: refData['bundleSource'] as String?,
          ),
        );
      }

      final preciseRefs = <PreciseReference>[];
      final preciseRefsData =
          stateData['preciseReferences'] as List? ?? const [];
      for (final raw in preciseRefsData) {
        if (raw is! Map) {
          continue;
        }

        final refData = Map<String, dynamic>.from(raw);
        final imageBytes = refData['image'] as Uint8List?;
        if (imageBytes == null || imageBytes.isEmpty) {
          continue;
        }

        final typeStr =
            refData['type'] as String? ??
            PreciseRefType.character.toApiString();
        final type = PreciseRefType.values.firstWhere(
          (item) => item.toApiString() == typeStr,
          orElse: () => PreciseRefType.character,
        );

        final isNormalizedPng = refData['isNormalizedPng'] as bool? ?? false;
        final referenceImage = isNormalizedPng
            ? NAIApiUtils.markNormalizedPreciseReferencePng(imageBytes)
            : imageBytes;

        preciseRefs.add(
          PreciseReference(
            image: referenceImage,
            type: type,
            strength: (refData['strength'] as num?)?.toDouble() ?? 1.0,
            fidelity: (refData['fidelity'] as num?)?.toDouble() ?? 1.0,
            enabled: refData['enabled'] as bool? ?? true,
          ),
        );
      }

      for (final vibe in restoredVibes) {
        _primeVibeEncodingCache(vibe);
      }

      // 更新状态
      state = state.copyWith(
        vibeReferencesV4: restoredVibes,
        preciseReferences: preciseRefs,
        normalizeVibeStrength:
            stateData['normalizeVibeStrength'] as bool? ?? true,
      );
      restoredVibeCount = restoredVibes.length;
      restoredPreciseRefCount = preciseRefs.length;

      _hasRestoredGenerationState = true;
      shouldRewriteGenerationState = true;

      AppLogger.d(
        'Generation state restored: ${restoredVibes.length} vibes, ${preciseRefs.length} precise refs',
        'GenerationParams',
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to restore generation state', e, stackTrace);
    } finally {
      _isRestoringGenerationState = false;
      if (shouldRewriteGenerationState && !_isDisposed) {
        unawaited(saveGenerationState());
      }
      span.finish(
        details: {
          'jsonChars': jsonChars,
          'restoredVibes': restoredVibeCount,
          'restoredPreciseRefs': restoredPreciseRefCount,
          'rewriteQueued': shouldRewriteGenerationState,
        },
      );
    }
  }

  // ==================== 多角色参数 (V4 模型) ====================

  /// 添加角色
  void addCharacter(CharacterPrompt character) {
    if (state.characters.length >= 6) return; // 最多6个角色
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final advancedExpanded = prefs.getBool(
        'generation_advanced_options_expanded',
      );
      if (advancedExpanded != null) {
        state = state.copyWith(advancedOptionsExpanded: advancedExpanded);
      }
    } catch (e) {
      AppLogger.e('Failed to load panel states', e);
    }
  }

  /// 保存面板展开状态
  Future<void> savePanelStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'generation_advanced_options_expanded',
        state.advancedOptionsExpanded,
      );
    } catch (e) {
      AppLogger.e('Failed to save panel states', e);
    }
  }

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

Map<String, Object?> _buildGenerationStateSaveInput({
  required List<VibeReference> vibeReferences,
  required List<PreciseReference> preciseReferences,
  required bool normalizeVibeStrength,
}) {
  return {
    'vibeReferences': vibeReferences
        .map((vibe) {
          return <String, Object?>{
            'displayName': vibe.displayName,
            'vibeEncoding': vibe.vibeEncoding,
            'strength': vibe.strength,
            'infoExtracted': vibe.infoExtracted,
            'sourceType': vibe.sourceType.name,
            'enabled': vibe.enabled,
            'bundleSource': vibe.bundleSource,
            'thumbnail': vibe.thumbnail,
            'rawImageData': vibe.rawImageData,
          };
        })
        .toList(growable: false),
    'preciseReferences': preciseReferences
        .map((reference) {
          return <String, Object?>{
            'type': reference.type.toApiString(),
            'strength': reference.strength,
            'fidelity': reference.fidelity,
            'enabled': reference.enabled,
            'image': reference.image,
            'isNormalizedPng': NAIApiUtils.isKnownNormalizedPreciseReferencePng(
              reference.image,
            ),
          };
        })
        .toList(growable: false),
    'normalizeVibeStrength': normalizeVibeStrength,
    'savedAt': DateTime.now().toIso8601String(),
  };
}

String _encodeGenerationStateJson(Map<String, Object?> input) {
  final rawVibes = input['vibeReferences'] as List? ?? const [];
  final vibeReferences = rawVibes
      .whereType<Map>()
      .map((raw) {
        final thumbnail = raw['thumbnail'] as Uint8List?;
        final rawImageData = raw['rawImageData'] as Uint8List?;
        final previewBytes = thumbnail ?? rawImageData;
        final previewDuplicatesRaw =
            previewBytes != null &&
            rawImageData != null &&
            _bytesEqualForGenerationState(previewBytes, rawImageData);

        return <String, Object?>{
          'displayName': raw['displayName'],
          'vibeEncoding': raw['vibeEncoding'],
          'strength': raw['strength'],
          'infoExtracted': raw['infoExtracted'],
          'sourceType': raw['sourceType'],
          'enabled': raw['enabled'] as bool? ?? true,
          'bundleSource': raw['bundleSource'],
          'thumbnailBase64': previewBytes != null && !previewDuplicatesRaw
              ? base64Encode(previewBytes)
              : null,
          'rawImageDataBase64': rawImageData != null
              ? base64Encode(rawImageData)
              : null,
        };
      })
      .toList(growable: false);

  final rawPreciseRefs = input['preciseReferences'] as List? ?? const [];
  final preciseReferences = rawPreciseRefs
      .whereType<Map>()
      .map((raw) {
        final image = raw['image'] as Uint8List?;
        return <String, Object?>{
          'type': raw['type'],
          'strength': raw['strength'],
          'fidelity': raw['fidelity'],
          'enabled': raw['enabled'] as bool? ?? true,
          'imageBase64': image != null ? base64Encode(image) : null,
          'isNormalizedPng': raw['isNormalizedPng'] as bool? ?? false,
        };
      })
      .toList(growable: false);

  return jsonEncode({
    'vibeReferences': vibeReferences,
    'preciseReferences': preciseReferences,
    'normalizeVibeStrength': input['normalizeVibeStrength'] as bool? ?? true,
    'savedAt': input['savedAt'],
  });
}

Map<String, Object?> _decodeGenerationStateJson(String jsonString) {
  final rawStateData = jsonDecode(jsonString) as Map<String, dynamic>;

  final restoredVibes = <Map<String, Object?>>[];
  final vibeRefsData = rawStateData['vibeReferences'] as List?;
  if (vibeRefsData != null) {
    for (var i = 0; i < vibeRefsData.length; i++) {
      final raw = vibeRefsData[i];
      if (raw is! Map) {
        continue;
      }

      final refData = Map<String, dynamic>.from(raw);
      final thumbnailBytes = _decodeGenerationStateBase64(
        refData['thumbnailBase64'] as String?,
      );
      final rawImageBytes = _decodeGenerationStateBase64(
        refData['rawImageDataBase64'] as String?,
      );

      restoredVibes.add(<String, Object?>{
        'displayName': refData['displayName'] as String? ?? 'Vibe ${i + 1}',
        'vibeEncoding': refData['vibeEncoding'] as String? ?? '',
        'thumbnail': thumbnailBytes ?? rawImageBytes,
        'rawImageData': rawImageBytes,
        'strength': (refData['strength'] as num?)?.toDouble() ?? 0.6,
        'infoExtracted': (refData['infoExtracted'] as num?)?.toDouble() ?? 0.7,
        'sourceType': refData['sourceType'] as String?,
        'enabled': refData['enabled'] as bool? ?? true,
        'bundleSource': refData['bundleSource'] as String?,
      });
    }
  } else {
    final legacyVibeEncodings =
        (rawStateData['vibeEntryIds'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    for (var i = 0; i < legacyVibeEncodings.length; i++) {
      final encoding = legacyVibeEncodings[i];
      if (encoding.isEmpty) {
        continue;
      }

      restoredVibes.add(<String, Object?>{
        'displayName': 'Vibe ${i + 1}',
        'vibeEncoding': encoding,
        'sourceType': VibeSourceType.naiv4vibe.name,
        'enabled': true,
      });
    }
  }

  final restoredPreciseRefs = <Map<String, Object?>>[];
  final preciseRefsData = rawStateData['preciseReferences'] as List?;
  if (preciseRefsData != null) {
    for (final raw in preciseRefsData) {
      if (raw is! Map) {
        continue;
      }

      final refData = Map<String, dynamic>.from(raw);
      final imageBytes = _decodeGenerationStateBase64(
        refData['imageBase64'] as String?,
      );
      if (imageBytes == null || imageBytes.isEmpty) {
        continue;
      }

      restoredPreciseRefs.add(<String, Object?>{
        'type':
            refData['type'] as String? ??
            PreciseRefType.character.toApiString(),
        'strength': (refData['strength'] as num?)?.toDouble() ?? 1.0,
        'fidelity': (refData['fidelity'] as num?)?.toDouble() ?? 1.0,
        'enabled': refData['enabled'] as bool? ?? true,
        'image': (refData['isNormalizedPng'] as bool? ?? false)
            ? NAIApiUtils.markNormalizedPreciseReferencePng(imageBytes)
            : imageBytes,
        'isNormalizedPng': refData['isNormalizedPng'] as bool? ?? false,
      });
    }
  }

  return {
    'vibeReferences': restoredVibes,
    'preciseReferences': restoredPreciseRefs,
    'normalizeVibeStrength':
        rawStateData['normalizeVibeStrength'] as bool? ?? true,
  };
}

Uint8List? _decodeGenerationStateBase64(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

bool _bytesEqualForGenerationState(Uint8List left, Uint8List right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;

  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
