import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/vibe_file_parser.dart';
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
    try {
      final entries = await _storageService.getRecentEntries(limit: 20);
      final uniqueEntries = entries.deduplicateByEncodingAndThumbnail(limit: 5);
      state = state.copyWith(recentEntries: uniqueEntries);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load recent vibes', e, stackTrace);
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
    final allEntries = await _storageService.getAllEntries();
    return allEntries.findMatchingEntry(vibe);
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReference>?> encodeVibesNow(
    List<VibeReference> vibes, {
    required String model,
  }) async {
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
            encodedVibes.add(
              vibe.copyWith(
                vibeEncoding: encoding,
                sourceType: VibeSourceType.naiv4vibe,
                rawImageData: null,
              ),
            );
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

      for (final vibe in vibes) {
        final vibeWithParams = vibe.copyWith(
          strength: strength,
          infoExtracted: infoExtracted,
        );

        final existingEntry = await findExistingEntry(vibe);

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
    return _addBundleVibesToGeneration(
      entry: entry,
      maxCount: maxCount,
    );
  }

  Future<int> _addBundleVibesToGeneration({
    required VibeLibraryEntry entry,
    required int maxCount,
  }) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = maxCount - currentCount;

    if (availableSlots <= 0 || entry.filePath == null) return 0;

    try {
      final fileStorage = VibeFileStorageService();
      final extractedVibes = <VibeReference>[];

      for (int i = 0;
          i < entry.bundledVibeCount.clamp(0, availableSlots);
          i++) {
        final vibe =
            await fileStorage.extractVibeFromBundle(entry.filePath!, i);
        if (vibe != null) {
          extractedVibes.add(vibe);
          recordBundleSource(vibe.displayName, entry.displayName);
        }
      }

      if (extractedVibes.isNotEmpty) {
        notifier.addVibeReferences(extractedVibes);
      }

      return extractedVibes.length;
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败', e, stackTrace);
      return 0;
    }
  }

  /// 添加最近使用的 Vibe
  Future<bool> addRecentVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    if (vibes.length >= 16) {
      return false;
    }

    if (entry.isBundle) {
      final added = await _addBundleVibesToGeneration(
        entry: entry,
        maxCount: 16,
      );
      if (added > 0) {
        await _storageService.incrementUsedCount(entry.id);
        await _loadRecentEntries();
      }
      return added > 0;
    }

    final vibe = entry.toVibeReference();
    notifier.addVibeReferences([vibe]);
    await _storageService.incrementUsedCount(entry.id);
    await _loadRecentEntries();

    return true;
  }

  /// 从库中添加 Vibe（用于拖拽）
  Future<bool> addLibraryVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    if (vibes.length >= 16) {
      return false;
    }

    if (entry.isBundle) {
      final added = await _addBundleVibesToGeneration(
        entry: entry,
        maxCount: 16,
      );
      if (added > 0) {
        await _storageService.incrementUsedCount(entry.id);
      }
      return added > 0;
    }

    final vibe = entry.toVibeReference();
    notifier.addVibeReferences([vibe]);
    await _storageService.incrementUsedCount(entry.id);

    return true;
  }

  /// 从 bundle 中提取并添加所有 vibes
  Future<int> addVibesFromBundle(VibeLibraryEntry entry) async {
    if (entry.filePath == null) {
      return 0;
    }

    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = 16 - currentCount;

    if (availableSlots <= 0) {
      return 0;
    }

    final added = await _addBundleVibesToGeneration(
      entry: entry,
      maxCount: 16,
    );

    if (added > 0) {
      await _storageService.incrementUsedCount(entry.id);
      await _loadRecentEntries();
    }

    return added;
  }

  /// 解析并添加 Vibe 文件
  Future<List<VibeReference>?> parseVibeFile(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      return await VibeFileParser.parseFile(fileName, bytes);
    } catch (e) {
      AppLogger.e('Failed to parse vibe file: $fileName', e);
      return null;
    }
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

/// VibeLibraryEntry 列表扩展方法
extension VibeLibraryEntryListExtension on List<VibeLibraryEntry> {
  /// 按编码和缩略图去重
  List<VibeLibraryEntry> deduplicateByEncodingAndThumbnail({int limit = 5}) {
    final seenEncodings = <String>{};
    final seenImageHashes = <String>{};
    final uniqueEntries = <VibeLibraryEntry>[];

    for (final entry in this) {
      if (entry.vibeEncoding.isNotEmpty) {
        if (seenEncodings.contains(entry.vibeEncoding)) {
          continue;
        }
        seenEncodings.add(entry.vibeEncoding);
        uniqueEntries.add(entry);
      } else if (entry.hasThumbnail && entry.thumbnail != null) {
        final hash = _calculateVibeThumbnailHash(entry.thumbnail!);
        if (seenImageHashes.contains(hash)) {
          continue;
        }
        seenImageHashes.add(hash);
        uniqueEntries.add(entry);
      } else {
        uniqueEntries.add(entry);
      }

      if (uniqueEntries.length >= limit) {
        break;
      }
    }

    return uniqueEntries;
  }

  /// 查找匹配的条目
  VibeLibraryEntry? findMatchingEntry(VibeReference vibe) {
    if (vibe.vibeEncoding.isNotEmpty) {
      for (final entry in this) {
        if (entry.vibeEncoding.isNotEmpty &&
            entry.vibeEncoding == vibe.vibeEncoding) {
          return entry;
        }
      }
      return null;
    }

    if (vibe.thumbnail != null) {
      final vibeHash = _calculateVibeThumbnailHash(vibe.thumbnail!);
      for (final entry in this) {
        if (entry.hasThumbnail && entry.thumbnail != null) {
          final entryHash = _calculateVibeThumbnailHash(entry.thumbnail!);
          if (entryHash == vibeHash) {
            return entry;
          }
        }
      }
      return null;
    }

    for (final entry in this) {
      if (entry.vibeDisplayName == vibe.displayName) {
        return entry;
      }
    }

    return null;
  }
}

String _calculateVibeThumbnailHash(Uint8List data) {
  return sha256.convert(data).toString().substring(0, 16);
}
