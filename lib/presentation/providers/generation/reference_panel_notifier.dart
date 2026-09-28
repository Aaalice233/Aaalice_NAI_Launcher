import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/extensions/vibe_library_extensions.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_file_storage_service.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import 'generation_params_notifier.dart';

part 'reference_panel_notifier.g.dart';

/// 引用面板 UI 状态
@Riverpod(keepAlive: true)
class ReferencePanelNotifier extends _$ReferencePanelNotifier {
  VibeLibraryStorageService get _storageService =>
      ref.read(vibeLibraryStorageServiceProvider);

  @override
  ReferencePanelState build() {
    // 初始化时加载状态
    _loadRecentCollapsedState();
    _loadRecentEntries();

    return const ReferencePanelState();
  }

  /// 加载最近使用区域的折叠状态
  Future<void> _loadRecentCollapsedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed = prefs.getBool(StorageKeys.vibeRecentCollapsed);
      state = state.copyWith(isRecentCollapsed: collapsed ?? true);
    } catch (e) {
      AppLogger.e('Failed to load recent collapsed state', e);
    }
  }

  /// 保存最近使用区域的折叠状态
  Future<void> _saveRecentCollapsedState(bool collapsed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.vibeRecentCollapsed, collapsed);
    } catch (e) {
      AppLogger.e('Failed to save recent collapsed state', e);
    }
  }

  /// 切换最近使用区域的折叠状态
  Future<void> toggleRecentCollapsed() async {
    final newState = !state.isRecentCollapsed;
    state = state.copyWith(isRecentCollapsed: newState);
    await _saveRecentCollapsedState(newState);
  }

  /// 设置最近使用区域的折叠状态
  Future<void> setRecentCollapsed(bool collapsed) async {
    state = state.copyWith(isRecentCollapsed: collapsed);
    await _saveRecentCollapsedState(collapsed);
  }

  /// 切换面板展开状态
  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  /// 设置面板展开状态
  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }

  /// 设置拖拽悬停状态
  void setDraggingOver(bool draggingOver) {
    state = state.copyWith(isDraggingOver: draggingOver);
  }

  /// 加载最近使用的条目
  Future<void> loadRecentEntries() async {
    await _loadRecentEntries();
  }

  Future<void> _loadRecentEntries() async {
    final span = VibePerformanceDiagnostics.start(
      'referencePanel.loadRecentEntries',
    );
    var entryCount = 0;
    var uniqueCount = 0;
    try {
      final entries = await _storageService.getRecentDisplayEntries(limit: 20);
      entryCount = entries.length;
      final uniqueEntries = entries.deduplicateByEncodingAndThumbnail(limit: 5);
      uniqueCount = uniqueEntries.length;
      state = state.copyWith(recentEntries: uniqueEntries);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load recent vibes', e, stackTrace);
    } finally {
      span.finish(
        details: {'entries': entryCount, 'uniqueEntries': uniqueCount},
      );
    }
  }

  /// 记录 Vibe 的 Bundle 来源
  void recordBundleSource(String vibeName, String bundleName) {
    final newSources = Map<String, String>.from(state.vibeBundleSources)
      ..[vibeName] = bundleName;
    state = state.copyWith(vibeBundleSources: newSources);
  }

  /// 移除 Vibe 的 Bundle 来源记录
  void removeBundleSource(String vibeName) {
    if (state.vibeBundleSources.containsKey(vibeName)) {
      final newSources = Map<String, String>.from(state.vibeBundleSources)
        ..remove(vibeName);
      state = state.copyWith(vibeBundleSources: newSources);
    }
  }

  /// 清空所有 Bundle 来源记录
  void clearBundleSources() {
    state = state.copyWith(vibeBundleSources: {});
  }

  /// 获取指定 Vibe 的 Bundle 来源
  String? getBundleSource(String vibeName) {
    return state.vibeBundleSources[vibeName];
  }

  /// 从库中查找已存在的相同 vibe 条目
  /// 基于 vibeEncoding 或缩略图哈希进行匹配
  Future<VibeLibraryEntry?> findExistingEntry(VibeReference vibe) async {
    return _storageService.findMatchingEntry(vibe);
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReference>?> encodeVibesNow(
    List<VibeReference> vibes, {
    required String model,
  }) async {
    if (!ModelCapabilityRegistry.of(model).supportsEncodedVibeTransfer) {
      return vibes;
    }
    final notifier = ref.read(generationParamsNotifierProvider.notifier);

    try {
      final encodedVibes = <VibeReference>[];
      for (final vibe in vibes) {
        if (vibe.sourceType == VibeSourceType.rawImage &&
            vibe.rawImageData != null) {
          final encoding = await notifier.encodeVibeWithCache(
            vibe.rawImageData!,
            model: model,
            informationExtracted: vibe.infoExtracted,
            vibeName: vibe.displayName,
          );

          if (encoding != null) {
            encodedVibes.add(vibe.withEncodedVibe(encoding, model: model));
          } else {
            encodedVibes.add(vibe);
          }
        } else {
          encodedVibes.add(vibe);
        }
      }

      return encodedVibes;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace);
      return null;
    }
  }

  /// 保存已编码的 Vibes 到库
  Future<SaveToLibraryResult> saveEncodedVibesToLibrary(
    List<VibeReference> vibes,
    String baseName,
  ) async {
    try {
      var savedCount = 0;
      var reusedCount = 0;

      for (final vibe in vibes) {
        final existingEntry = await findExistingEntry(vibe);

        if (existingEntry != null) {
          await _storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
        } else {
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1
                ? baseName
                : '$baseName - ${vibe.displayName}',
            vibeData: vibe,
          );
          await _storageService.saveEntry(entry);
          savedCount++;
        }
      }

      // 刷新最近列表
      await _loadRecentEntries();

      return SaveToLibraryResult(
        savedCount: savedCount,
        reusedCount: reusedCount,
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save encoded vibes to library', e, stackTrace);
      return const SaveToLibraryResult(savedCount: 0, reusedCount: 0);
    }
  }

  /// 保存当前 Vibes 到库（支持命名和参数设置）
  Future<SaveToLibraryResult> saveCurrentVibesToLibrary(
    List<VibeReference> vibes,
    String name, {
    double strength = 0.6,
    double infoExtracted = 0.7,
  }) async {
    if (vibes.isEmpty) {
      return const SaveToLibraryResult(savedCount: 0, reusedCount: 0);
    }

    try {
      var savedCount = 0;
      var reusedCount = 0;
      final generationParams = ref.read(generationParamsNotifierProvider);
      final paramsNotifier = ref.read(
        generationParamsNotifierProvider.notifier,
      );

      for (final vibe in vibes) {
        final preparedVibe = await paramsNotifier
            .prepareVibeForLibraryParamSave(
              vibe,
              strength: strength,
              infoExtracted: infoExtracted,
              model: generationParams.model,
            );
        if (preparedVibe == null) {
          return SaveToLibraryResult(
            savedCount: savedCount,
            reusedCount: reusedCount,
          );
        }

        final vibeWithParams = preparedVibe.normalizedForLibraryStorage();

        final existingEntry = await findExistingEntry(vibeWithParams);

        if (existingEntry != null) {
          await _storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
        } else {
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1 ? name : '$name - ${vibe.displayName}',
            vibeData: vibeWithParams,
          );
          await _storageService.saveEntry(entry);
          savedCount++;
        }
      }

      // 刷新最近列表
      await _loadRecentEntries();

      return SaveToLibraryResult(
        savedCount: savedCount,
        reusedCount: reusedCount,
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save to library', e, stackTrace);
      return const SaveToLibraryResult(savedCount: 0, reusedCount: 0);
    }
  }

  /// 从 bundle 提取 vibes 并添加到生成参数
  /// 返回实际添加的数量
  Future<int> extractAndAddBundleVibes(
    VibeLibraryEntry entry, {
    required int maxCount,
  }) async {
    return _addBundleVibesToGeneration(entry: entry, maxCount: maxCount);
  }

  Future<int> _addBundleVibesToGeneration({
    required VibeLibraryEntry entry,
    required int maxCount,
  }) async {
    final span = VibePerformanceDiagnostics.start(
      'referencePanel.addBundleVibesToGeneration',
      details: {
        'entryId': entry.id,
        'bundledVibes': entry.bundledVibeCount,
        'maxCount': maxCount,
      },
    );
    var extractedCount = 0;
    var availableSlots = 0;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentCount = ref
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .length;
    availableSlots = maxCount - currentCount;

    try {
      if (availableSlots <= 0 || entry.filePath == null) return 0;

      final fileStorage = VibeFileStorageService();
      final extractLimit = entry.bundledVibeCount
          .clamp(0, availableSlots)
          .toInt();
      final extractedVibes = await fileStorage.extractVibesFromBundle(
        entry.filePath!,
        limit: extractLimit,
      );

      for (final vibe in extractedVibes) {
        recordBundleSource(vibe.displayName, entry.displayName);
      }

      if (extractedVibes.isNotEmpty) {
        notifier.addVibeReferences(extractedVibes, recordUsage: false);
      }
      extractedCount = extractedVibes.length;

      return extractedVibes.length;
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败', e, stackTrace);
      return 0;
    } finally {
      span.finish(
        details: {
          'availableSlots': availableSlots,
          'extracted': extractedCount,
        },
      );
    }
  }

  /// 添加最近使用的 Vibe
  Future<bool> addRecentVibe(VibeLibraryEntry entry) async {
    final span = VibePerformanceDiagnostics.start(
      'referencePanel.addRecentVibe',
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
    );
    var success = false;
    var addedFromBundle = 0;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;
    final actualEntry = await _storageService.getEntry(entry.id) ?? entry;

    try {
      if (vibes.length >= 16) {
        return false;
      }

      if (actualEntry.isBundle) {
        addedFromBundle = await _addBundleVibesToGeneration(
          entry: actualEntry,
          maxCount: 16,
        );
        if (addedFromBundle > 0) {
          await _storageService.incrementUsedCount(actualEntry.id);
          await _loadRecentEntries();
        }
        success = addedFromBundle > 0;
        return success;
      }

      final vibe = actualEntry.toVibeReference();
      notifier.addVibeReferences([vibe], recordUsage: false);
      await _storageService.incrementUsedCount(actualEntry.id);
      await _loadRecentEntries();

      success = true;
      return true;
    } finally {
      span.finish(
        details: {'success': success, 'addedFromBundle': addedFromBundle},
      );
    }
  }

  /// 从库中添加 Vibe（用于拖拽）
  Future<bool> addLibraryVibe(VibeLibraryEntry entry) async {
    final span = VibePerformanceDiagnostics.start(
      'referencePanel.addLibraryVibe',
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
    );
    var success = false;
    var addedFromBundle = 0;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;
    final actualEntry = await _storageService.getEntry(entry.id) ?? entry;

    try {
      if (vibes.length >= 16) {
        return false;
      }

      if (actualEntry.isBundle) {
        addedFromBundle = await _addBundleVibesToGeneration(
          entry: actualEntry,
          maxCount: 16,
        );
        if (addedFromBundle > 0) {
          await _storageService.incrementUsedCount(actualEntry.id);
        }
        success = addedFromBundle > 0;
        return success;
      }

      final vibe = actualEntry.toVibeReference();
      notifier.addVibeReferences([vibe], recordUsage: false);
      await _storageService.incrementUsedCount(actualEntry.id);

      success = true;
      return true;
    } finally {
      span.finish(
        details: {'success': success, 'addedFromBundle': addedFromBundle},
      );
    }
  }

  /// 从 bundle 中提取并添加所有 vibes
  Future<int> addVibesFromBundle(VibeLibraryEntry entry) async {
    final span = VibePerformanceDiagnostics.start(
      'referencePanel.addVibesFromBundle',
      details: {'entryId': entry.id, 'bundledVibes': entry.bundledVibeCount},
    );
    var added = 0;
    try {
      if (entry.filePath == null) {
        return 0;
      }

      final currentCount = ref
          .read(generationParamsNotifierProvider)
          .vibeReferencesV4
          .length;
      final availableSlots = 16 - currentCount;

      if (availableSlots <= 0) {
        return 0;
      }

      added = await _addBundleVibesToGeneration(entry: entry, maxCount: 16);

      if (added > 0) {
        await _storageService.incrementUsedCount(entry.id);
        await _loadRecentEntries();
      }

      return added;
    } finally {
      span.finish(details: {'added': added});
    }
  }

  /// 解析并添加 Vibe 文件
  Future<List<VibeReference>?> parseVibeFile(
    String fileName,
    Uint8List bytes,
  ) async {
    return VibePerformanceDiagnostics.measure(
      'referencePanel.parseVibeFile',
      () async {
        try {
          return await VibeFileParser.parseFile(fileName, bytes);
        } catch (e) {
          AppLogger.e('Failed to parse vibe file: $fileName', e);
          return null;
        }
      },
      details: {'bytes': bytes.length},
      resultDetails: (vibes) => {'parsedVibes': vibes?.length ?? 0},
    );
  }

  /// 检查 vibes 是否需要编码
  bool needsEncoding(List<VibeReference> vibes) {
    return vibes.any((v) => v.sourceType == VibeSourceType.rawImage);
  }
}

/// 引用面板状态类
class ReferencePanelState {
  final bool isExpanded;
  final bool isRecentCollapsed;
  final bool isDraggingOver;
  final List<VibeLibraryEntry> recentEntries;
  final Map<String, String> vibeBundleSources;

  const ReferencePanelState({
    this.isExpanded = false,
    this.isRecentCollapsed = true,
    this.isDraggingOver = false,
    this.recentEntries = const [],
    this.vibeBundleSources = const {},
  });

  ReferencePanelState copyWith({
    bool? isExpanded,
    bool? isRecentCollapsed,
    bool? isDraggingOver,
    List<VibeLibraryEntry>? recentEntries,
    Map<String, String>? vibeBundleSources,
  }) {
    return ReferencePanelState(
      isExpanded: isExpanded ?? this.isExpanded,
      isRecentCollapsed: isRecentCollapsed ?? this.isRecentCollapsed,
      isDraggingOver: isDraggingOver ?? this.isDraggingOver,
      recentEntries: recentEntries ?? this.recentEntries,
      vibeBundleSources: vibeBundleSources ?? this.vibeBundleSources,
    );
  }
}

/// 保存到库的结果
class SaveToLibraryResult {
  final int savedCount;
  final int reusedCount;

  const SaveToLibraryResult({
    required this.savedCount,
    required this.reusedCount,
  });

  bool get hasSaved => savedCount > 0 || reusedCount > 0;
}
