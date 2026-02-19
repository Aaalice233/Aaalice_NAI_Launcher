import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_library_storage_service.dart';

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
  bool _isRestoringGenerationState = false;
  bool _hasRestoredGenerationState = false;

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

  Uint8List? _decodeBase64Safely(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return base64Decode(value);
    } catch (e) {
      AppLogger.w(
        'Failed to decode base64 field in generation state: $e',
        'GenerationParams',
      );
      return null;
    }
  }

  /// 加载最近使用的 Vibes
  Future<void> loadRecentVibes() async {
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final entries = await storageService.getRecentEntries(limit: 20);
      _recentVibes = entries;
      // 通知监听器更新
      state = state.copyWith();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load recent vibes', e, stackTrace);
    }
  }

  /// 记录 Vibe 使用并更新最近列表
  Future<void> _recordVibeUsage(VibeReference vibe) async {
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);

      // 使用全量条目查重，避免最近列表未刷新导致重复写入
      final allEntries = await storageService.getAllEntries();
      VibeLibraryEntry? existingEntry;

      // 优先按 vibeEncoding 精确匹配
      if (vibe.vibeEncoding.isNotEmpty) {
        for (final entry in allEntries) {
          if (entry.vibeEncoding.isNotEmpty &&
              entry.vibeEncoding == vibe.vibeEncoding) {
            existingEntry = entry;
            break;
          }
        }
      }

      // 回退到 displayName 匹配（兼容历史数据）
      if (existingEntry == null) {
        for (final entry in allEntries) {
          if (entry.vibeDisplayName == vibe.displayName) {
            existingEntry = entry;
            break;
          }
        }
      }

      if (existingEntry != null) {
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
      }

      // 重新加载最近列表
      await loadRecentVibes();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to record vibe usage', e, stackTrace);
    }
  }

  @override
  ImageParams build() {
    ref.onDispose(() {
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
      final seedToLock =
          currentSeed == -1 ? Random().nextInt(4294967295) : currentSeed;
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

  // ==================== V4 Vibe Transfer 参数 ====================

  /// 添加 V4 Vibe 参考
  /// 支持预编码 (.naiv4vibe, PNG 带元数据)
  /// 对于原始图片，会自动检查编码缓存避免重复 API 调用
  void addVibeReference(VibeReference vibe) {
    if (state.vibeReferencesV4.length >= 16) return; // V4 支持最多 16 张

    var vibeToAdd = vibe;

    // 检查是否是原始图片且需要编码
    if (vibe.sourceType == VibeSourceType.rawImage &&
        vibe.vibeEncoding.isEmpty &&
        vibe.rawImageData != null) {
      // 计算图片哈希
      final imageHash = _calculateImageHash(vibe.rawImageData!);

      // 检查缓存
      if (_vibeEncodingCache.containsKey(imageHash)) {
        // 缓存命中 - 使用缓存的编码
        final cachedEncoding = _vibeEncodingCache[imageHash]!;
        AppLogger.i(
          'Vibe 编码缓存命中: ${vibe.displayName}',
          'VibeCache',
        );

        // 更新 vibe 使用缓存的编码
        vibeToAdd = vibe.copyWith(vibeEncoding: cachedEncoding);

        // 显示缓存命中通知
        _showCacheHitNotification(vibe.displayName);
      }
    }

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

  /// 显示缓存命中通知
  void _showCacheHitNotification(String vibeName) {
    // 使用 AppLogger 记录，UI 层可以监听并显示 Toast
    AppLogger.i(
      'Vibe 编码已从缓存加载: $vibeName',
      'VibeCache',
    );
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
    // 计算图片哈希
    final imageHash = _calculateImageHash(imageData);

    // 检查缓存
    if (_vibeEncodingCache.containsKey(imageHash)) {
      AppLogger.i(
        'Vibe 编码缓存命中: ${vibeName ?? 'unknown'}',
        'VibeCache',
      );
      _showCacheHitNotification(vibeName ?? 'unknown');
      return _vibeEncodingCache[imageHash];
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
      _vibeEncodingCache[imageHash] = encoding;
      AppLogger.i(
        'Vibe 编码已缓存: ${vibeName ?? 'unknown'}',
        'VibeCache',
      );

      return encoding;
    } catch (e, stack) {
      AppLogger.e(
        'Vibe 编码失败: ${vibeName ?? 'unknown'}',
        e,
        stack,
        'VibeCache',
      );
      return null;
    }
  }

  /// 将编码存入缓存（供外部调用）
  ///
  /// [imageData] 原始图片数据
  /// [encoding] 编码后的 vibe 字符串
  void storeVibeEncodingInCache(Uint8List imageData, String encoding) {
    final imageHash = _calculateImageHash(imageData);
    _vibeEncodingCache[imageHash] = encoding;
    AppLogger.d(
      'Vibe 编码已手动存入缓存，当前缓存大小: ${_vibeEncodingCache.length}',
      'VibeCache',
    );
  }

  /// 获取缓存大小
  int get vibeEncodingCacheSize => _vibeEncodingCache.length;

  /// 清空编码缓存
  void clearVibeEncodingCache() {
    _vibeEncodingCache.clear();
    AppLogger.i('Vibe 编码缓存已清空', 'VibeCache');
  }

  /// 批量添加 V4 Vibe 参考
  /// 如果 vibe 已存在，会移除旧的并添加新的（调整顺序）
  void addVibeReferences(List<VibeReference> vibes) {
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
    newVibes = [...newVibes, ...canAdd, ...toReorder];

    // 限制最多 16 个（如果超过，保留后 16 个）
    if (newVibes.length > 16) {
      newVibes = newVibes.sublist(newVibes.length - 16);
    }

    // 更新状态
    state = state.copyWith(vibeReferencesV4: newVibes);
    _scheduleGenerationStateSave(immediate: true);

    // 记录使用
    for (final vibe in [...canAdd, ...toReorder]) {
      _recordVibeUsage(vibe);
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
  }) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    final current = newList[index];
    newList[index] = current.copyWith(
      strength: strength ?? current.strength,
      infoExtracted: infoExtracted ?? current.infoExtracted,
      vibeEncoding: vibeEncoding ?? current.vibeEncoding,
    );
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
    // 限制最多 16 个
    final limitedVibes = vibes.take(16).toList();
    state = state.copyWith(vibeReferencesV4: limitedVibes);
    _scheduleGenerationStateSave(immediate: true);
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
        final entry = VibeLibraryEntry.fromVibeReference(
          name: state.vibeReferencesV4.length == 1
              ? name
              : '$name (${vibe.displayName})',
          vibeData: vibe,
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
  }) {
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
  }) {
    if (index < 0 || index >= state.preciseReferences.length) return;
    final newList = [...state.preciseReferences];
    final current = newList[index];
    newList[index] = PreciseReference(
      image: current.image,
      type: type ?? current.type,
      strength: strength ?? current.strength,
      fidelity: fidelity ?? current.fidelity,
    );
    state = state.copyWith(preciseReferences: newList);
    _scheduleGenerationStateSave();
  }

  /// 更新 Precise Reference 类型
  void updatePreciseReferenceType(int index, PreciseRefType type) {
    if (index < 0 || index >= state.preciseReferences.length) return;
    final newList = [...state.preciseReferences];
    final current = newList[index];
    newList[index] = PreciseReference(
      image: current.image,
      type: type,
      strength: current.strength,
      fidelity: current.fidelity,
    );
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
  Future<void> saveGenerationState() async {
    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);

      final vibeReferences = state.vibeReferencesV4.map((vibe) {
        final previewBytes = vibe.thumbnail ?? vibe.rawImageData;
        return {
          'displayName': vibe.displayName,
          'vibeEncoding': vibe.vibeEncoding,
          'strength': vibe.strength,
          'infoExtracted': vibe.infoExtracted,
          'sourceType': vibe.sourceType.name,
          'thumbnailBase64':
              previewBytes != null ? base64Encode(previewBytes) : null,
          'rawImageDataBase64': vibe.rawImageData != null
              ? base64Encode(vibe.rawImageData!)
              : null,
        };
      }).toList(growable: false);

      // 保存精准参考数据
      final preciseRefs = state.preciseReferences.map((ref) {
        return {
          'type': ref.type.toApiString(),
          'strength': ref.strength,
          'fidelity': ref.fidelity,
          'imageBase64': base64Encode(ref.image),
        };
      }).toList();

      await storageService.saveGenerationState(
        vibeReferences: vibeReferences,
        preciseReferences: preciseRefs,
        normalizeVibeStrength: state.normalizeVibeStrength,
      );

      AppLogger.d('Generation state saved', 'GenerationParams');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save generation state', e, stackTrace);
    }
  }

  /// 恢复保存的 Vibe 和精准参考状态
  Future<void> restoreGenerationState() async {
    if (_hasRestoredGenerationState || _isRestoringGenerationState) {
      return;
    }

    _isRestoringGenerationState = true;

    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final stateData = await storageService.loadGenerationState();

      if (stateData == null) {
        _hasRestoredGenerationState = true;
        AppLogger.d('No saved generation state found', 'GenerationParams');
        return;
      }

      final restoredVibes = <VibeReference>[];
      final vibeRefsData = stateData['vibeReferences'] as List?;
      if (vibeRefsData != null) {
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
          final thumbnailBytes =
              _decodeBase64Safely(refData['thumbnailBase64'] as String?);
          final rawImageBytes = _decodeBase64Safely(
            refData['rawImageDataBase64'] as String?,
          );

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
            ),
          );
        }
      } else {
        final legacyVibeEncodings = (stateData['vibeEntryIds'] as List?)
                ?.whereType<String>()
                .toList() ??
            const <String>[];

        for (var i = 0; i < legacyVibeEncodings.length; i++) {
          final encoding = legacyVibeEncodings[i];
          if (encoding.isEmpty) {
            continue;
          }

          restoredVibes.add(
            VibeReference(
              displayName: 'Vibe ${i + 1}',
              vibeEncoding: encoding,
              sourceType: VibeSourceType.naiv4vibe,
            ),
          );
        }
      }

      final preciseRefs = <PreciseReference>[];
      final preciseRefsData = stateData['preciseReferences'] as List?;
      if (preciseRefsData != null) {
        for (final raw in preciseRefsData) {
          if (raw is! Map) {
            continue;
          }

          final refData = Map<String, dynamic>.from(raw);
          final imageBytes =
              _decodeBase64Safely(refData['imageBase64'] as String?);
          if (imageBytes == null || imageBytes.isEmpty) {
            continue;
          }

          final typeStr = refData['type'] as String? ??
              PreciseRefType.character.toApiString();
          final type = PreciseRefType.values.firstWhere(
            (item) => item.toApiString() == typeStr,
            orElse: () => PreciseRefType.character,
          );

          preciseRefs.add(
            PreciseReference(
              image: imageBytes,
              type: type,
              strength: (refData['strength'] as num?)?.toDouble() ?? 1.0,
              fidelity: (refData['fidelity'] as num?)?.toDouble() ?? 1.0,
            ),
          );
        }
      }

      // 更新状态
      state = state.copyWith(
        vibeReferencesV4: restoredVibes,
        preciseReferences: preciseRefs,
        normalizeVibeStrength:
            stateData['normalizeVibeStrength'] as bool? ?? true,
      );

      _hasRestoredGenerationState = true;

      AppLogger.d(
        'Generation state restored: ${restoredVibes.length} vibes, ${preciseRefs.length} precise refs',
        'GenerationParams',
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to restore generation state', e, stackTrace);
    } finally {
      _isRestoringGenerationState = false;
    }
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
