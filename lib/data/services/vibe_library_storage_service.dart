import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_performance_diagnostics.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_file_storage_service.dart';

part 'vibe_library_storage_categories.dart';
part 'vibe_library_storage_lifecycle.dart';
part 'vibe_library_storage_types.dart';
part 'vibe_library_storage_service.g.dart';

/// Vibe 库存储服务
///
/// 负责 Vibe 库条目和分类的 CRUD 操作
/// 使用 Hive 本地存储，支持搜索、筛选和使用统计
class VibeLibraryStorageService
    with VibeLibraryStorageLifecycle, VibeLibraryStorageCategories {
  static const String _entriesBoxName = 'vibe_library_entries';
  static const String _displayEntriesBoxName =
      'vibe_library_display_entries_v2';
  static const String _thumbnailCacheBoxName =
      'vibe_library_thumbnail_cache_v1';
  static const String _categoriesBoxName = 'vibe_library_categories';
  static const String _displayCacheReadyKey =
      'vibe_library_display_cache_ready_v2';
  static const int _displayThumbnailMaxDimension = 256;
  static const int _displayThumbnailInlineLimitBytes = 64 * 1024;
  static const int _displayThumbnailJpegQuality = 78;
  static const String _tag = 'VibeLibrary';

  VibeLibraryStorageService({VibeFileStorageService? fileStorage})
    : _fileStorage = fileStorage ?? VibeFileStorageService();

  Box<VibeLibraryEntry>? _entriesBox;
  LazyBox<VibeLibraryEntry>? _lazyEntriesBox;
  Box<VibeLibraryEntry>? _displayEntriesBox;
  Box<Uint8List>? _thumbnailCacheBox;
  Box<VibeLibraryCategory>? _categoriesBox;
  Future<void>? _entriesInitFuture;
  Future<void>? _lazyEntriesInitFuture;
  Future<void>? _displayEntriesInitFuture;
  Future<void>? _thumbnailCacheInitFuture;
  Future<void>? _categoriesInitFuture;
  Future<void> _thumbnailLoadQueue = Future.value();
  final Map<String, Future<Uint8List?>> _thumbnailLoadsById = {};
  final VibeFileStorageService _fileStorage;

  static Uint8List? _resizeDisplayThumbnailSync(Uint8List sourceBytes) {
    final source = img.decodeImage(sourceBytes);
    if (source == null) {
      return null;
    }

    final longestSide = math.max(source.width, source.height);
    if (longestSide <= _displayThumbnailMaxDimension &&
        sourceBytes.length <= _displayThumbnailInlineLimitBytes) {
      return sourceBytes;
    }

    final scale = _displayThumbnailMaxDimension / longestSide;
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());
    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: _displayThumbnailJpegQuality),
    );
  }

  Future<Uint8List?> _normalizeDisplayThumbnail(Uint8List sourceBytes) async {
    if (sourceBytes.isEmpty) {
      return null;
    }

    if (sourceBytes.length <= _displayThumbnailInlineLimitBytes) {
      return sourceBytes;
    }

    return Isolate.run(() => _resizeDisplayThumbnailSync(sourceBytes));
  }

  Uint8List? _pickDisplayThumbnailSource(VibeLibraryEntry entry) {
    final thumbnail = entry.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }

    final vibeThumbnail = entry.vibeThumbnail;
    if (vibeThumbnail != null && vibeThumbnail.isNotEmpty) {
      return vibeThumbnail;
    }

    final previews = entry.bundledVibePreviews;
    if (previews != null && previews.isNotEmpty && previews.first.isNotEmpty) {
      return previews.first;
    }

    final rawImageData = entry.rawImageData;
    if (rawImageData != null && rawImageData.isNotEmpty) {
      return rawImageData;
    }

    return null;
  }

  Future<Uint8List?> _loadAndCacheDisplayThumbnail(String id) async {
    final span = VibePerformanceDiagnostics.start(
      'storage.loadDisplayThumbnail',
      details: {'id': id},
    );
    var found = false;
    var cached = false;
    var sourceBytes = 0;
    var resultBytes = 0;
    try {
      await _ensureThumbnailCacheBox();
      final existing = _thumbnailCacheBox!.get(id);
      if (existing != null && existing.isNotEmpty) {
        cached = true;
        resultBytes = existing.length;
        return existing;
      }

      final entry = await _readStoredEntry(id);
      if (entry == null) {
        return null;
      }
      found = true;

      final source = _pickDisplayThumbnailSource(entry);
      if (source == null) {
        return null;
      }
      sourceBytes = source.length;

      final thumbnail = await _normalizeDisplayThumbnail(source);
      if (thumbnail == null || thumbnail.isEmpty) {
        return null;
      }

      resultBytes = thumbnail.length;
      await _thumbnailCacheBox!.put(id, thumbnail);
      return thumbnail;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load display thumbnail', e, stackTrace, _tag);
      return null;
    } finally {
      span.finish(
        details: {
          'found': found,
          'cached': cached,
          'sourceBytes': sourceBytes,
          'resultBytes': resultBytes,
        },
      );
    }
  }

  Future<Uint8List?> _queueDisplayThumbnailLoad(String id) {
    final queued = _thumbnailLoadQueue.then(
      (_) => _loadAndCacheDisplayThumbnail(id),
    );
    _thumbnailLoadQueue = queued.then<void>((_) {}, onError: (_) {});
    return queued;
  }

  /// 按需读取列表缩略图。
  ///
  /// 列表展示缓存本身不再携带图片字节，避免打开 Vibe 库时一次性加载
  /// 大量缩略图。卡片可调用该方法串行生成/读取小缩略图缓存。
  Future<Uint8List?> getDisplayThumbnail(String id) async {
    await _ensureThumbnailCacheBox();
    final cached = _thumbnailCacheBox!.get(id);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final activeLoad = _thumbnailLoadsById[id];
    if (activeLoad != null) {
      return activeLoad;
    }

    final load = _queueDisplayThumbnailLoad(id);
    _thumbnailLoadsById[id] = load;
    try {
      return await load;
    } finally {
      if (identical(_thumbnailLoadsById[id], load)) {
        _thumbnailLoadsById.remove(id);
      }
    }
  }

  Future<List<VibeLibraryEntry>> _rebuildDisplayEntriesCache() async {
    final span = VibePerformanceDiagnostics.start(
      'storage.rebuildDisplayEntriesCache',
    );
    var entryCount = 0;
    try {
      await _ensureDisplayEntriesBox();

      final displayEntries = <VibeLibraryEntry>[];
      await _forEachStoredEntryLazily((entry) async {
        displayEntries.add(entry.toDisplayEntry());

        // Hive lazy reads still decode the entry payload. Yield periodically so
        // the first library open can keep painting instead of monopolizing UI.
        await Future<void>.delayed(Duration.zero);
      });

      final entriesById = {for (final entry in displayEntries) entry.id: entry};

      await _displayEntriesBox!.clear();
      if (entriesById.isNotEmpty) {
        await _displayEntriesBox!.putAll(entriesById);
      }
      await _setDisplayCacheReady(true);

      entryCount = displayEntries.length;
      AppLogger.i(
        'Vibe display cache rebuilt: ${displayEntries.length} entries',
        _tag,
      );
      return displayEntries;
    } finally {
      span.finish(details: {'entries': entryCount});
    }
  }

  Future<VibeLibraryEntry?> _readStoredEntry(String id) async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      return _entriesBox!.get(id);
    }

    await _ensureLazyEntriesBox();
    return _lazyEntriesBox!.get(id);
  }

  Future<void> _putStoredEntry(VibeLibraryEntry entry) async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      await _entriesBox!.put(entry.id, entry);
      return;
    }

    await _ensureLazyEntriesBox();
    await _lazyEntriesBox!.put(entry.id, entry);
  }

  Future<void> _deleteStoredEntry(String id) async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      await _entriesBox!.delete(id);
      return;
    }

    await _ensureLazyEntriesBox();
    await _lazyEntriesBox!.delete(id);
  }

  Future<void> _clearStoredEntries() async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      await _entriesBox!.clear();
      return;
    }

    await _ensureLazyEntriesBox();
    await _lazyEntriesBox!.clear();
  }

  Future<void> _forEachStoredEntryLazily(
    Future<void> Function(VibeLibraryEntry entry) visit,
  ) async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      for (final entry in _entriesBox!.values) {
        await visit(entry);
      }
      return;
    }

    await _ensureLazyEntriesBox();
    final keys = _lazyEntriesBox!.keys.toList(growable: false);
    for (final key in keys) {
      final entry = await _lazyEntriesBox!.get(key);
      if (entry != null) {
        await visit(entry);
      }
    }
  }

  Future<VibeLibraryEntry?> _firstStoredEntryWhere(
    bool Function(VibeLibraryEntry entry) test,
  ) async {
    var checkedCount = 0;

    if (_entriesBox != null && _entriesBox!.isOpen) {
      for (final entry in _entriesBox!.values) {
        if (test(entry)) return entry;
        checkedCount++;
        if (checkedCount % 4 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return null;
    }

    await _ensureLazyEntriesBox();
    final keys = _lazyEntriesBox!.keys.toList(growable: false);
    for (final key in keys) {
      final entry = await _lazyEntriesBox!.get(key);
      if (entry != null && test(entry)) {
        return entry;
      }
      checkedCount++;
      if (checkedCount % 4 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return null;
  }

  bool _bytesEqual(Uint8List? left, Uint8List? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    if (left.length != right.length) return false;

    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Future<VibeLibraryEntry?> findMatchingEntry(VibeReference vibe) async {
    return VibePerformanceDiagnostics.measure(
      'storage.findMatchingEntry',
      () async {
        if (vibe.vibeEncoding.isNotEmpty) {
          final match = await _firstStoredEntryWhere((entry) {
            return entry.vibeEncoding.isNotEmpty &&
                entry.vibeEncoding == vibe.vibeEncoding;
          });
          if (match != null) return match;
        }

        final thumbnail = vibe.thumbnail;
        if (thumbnail != null && thumbnail.isNotEmpty) {
          return _firstStoredEntryWhere((entry) {
            return entry.hasThumbnail &&
                _bytesEqual(entry.thumbnail, thumbnail);
          });
        }

        return null;
      },
      details: {
        'hasEncoding': vibe.vibeEncoding.isNotEmpty,
        'hasThumbnail': vibe.thumbnail?.isNotEmpty == true,
      },
      resultDetails: (entry) => {'found': entry != null},
    );
  }

  Future<VibeLibraryEntry?> findOverwriteCandidate(
    List<VibeReference> vibes,
  ) async {
    return VibePerformanceDiagnostics.measure(
      'storage.findOverwriteCandidate',
      () async {
        if (vibes.length != 1) {
          return null;
        }

        final vibe = vibes.single;
        return _firstStoredEntryWhere((entry) {
          final sameDisplayName = entry.displayName == vibe.displayName;
          final sameEncoding = entry.vibeEncoding == vibe.vibeEncoding;
          final sameRawImage = _bytesEqual(
            entry.rawImageData,
            vibe.rawImageData,
          );
          return sameDisplayName && (sameEncoding || sameRawImage);
        });
      },
      details: {'vibes': vibes.length},
      resultDetails: (entry) => {'found': entry != null},
    );
  }

  Future<VibeLibraryEntry?> findEntryByName(String name) async {
    return VibePerformanceDiagnostics.measure(
      'storage.findEntryByName',
      () async {
        final normalizedName = name.trim().toLowerCase();
        if (normalizedName.isEmpty) {
          return null;
        }

        return _firstStoredEntryWhere((entry) {
          return entry.name.trim().toLowerCase() == normalizedName;
        });
      },
      details: {'hasName': name.trim().isNotEmpty},
      resultDetails: (entry) => {'found': entry != null},
    );
  }

  // ==================== Entry CRUD ====================

  /// 保存条目（新增或更新）
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    try {
      var entryToSave = entry.normalizedForLibraryStorage();
      final filePath = entryToSave.filePath;
      if (filePath == null || filePath.isEmpty) {
        entryToSave = await _saveEntryFile(entryToSave);
      }

      await _putStoredEntry(entryToSave);
      await _upsertDisplayEntryIfReady(entryToSave);
      await _deleteDisplayThumbnailCache(entryToSave.id);
      AppLogger.d('Entry saved: ${entryToSave.displayName}', _tag);
      return entryToSave;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save entry', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 显式保存条目参数。
  ///
  /// 仅在用户明确点击“保存参数”时调用；若条目绑定了单个 Vibe 文件，
  /// 会同步把文件里的 importInfo 一起更新，避免重新打开时被旧文件参数覆盖。
  Future<VibeLibraryEntry?> saveEntryParams(
    String id, {
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = persistedVibeData != null
          ? entry.updateVibeData(persistedVibeData)
          : entry.updateStrength(strength).updateInfoExtracted(infoExtracted);

      final filePath = updatedEntry.filePath;
      if (!updatedEntry.isBundle && filePath != null && filePath.isNotEmpty) {
        await _fileStorage.overwriteVibeFile(
          filePath,
          updatedEntry.toVibeReference(),
          displayName: updatedEntry.displayName,
        );
      }

      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      await _deleteDisplayThumbnailCache(updatedEntry.id);
      return await getEntry(updatedEntry.id) ?? updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save entry params', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 显式保存 bundle 中某个子 Vibe 的参数，并同步覆盖 bundle 文件。
  Future<VibeLibraryEntry?> saveBundleChildParams(
    String id, {
    required int childIndex,
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null || !entry.isBundle) return null;

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) return null;

      var vibes = await _fileStorage.extractVibesFromBundle(filePath);
      if (vibes.isEmpty) {
        vibes = _buildBundleVibeReferences(entry);
      }
      if (childIndex < 0 || childIndex >= vibes.length) return null;

      final updatedVibes = List<VibeReference>.from(vibes);
      final currentChild = updatedVibes[childIndex];
      updatedVibes[childIndex] = (persistedVibeData ?? currentChild)
          .copyWith(
            displayName: currentChild.displayName,
            bundleSource: currentChild.bundleSource,
            strength: VibeReference.sanitizeStrength(strength),
            infoExtracted: VibeReference.sanitizeInfoExtracted(infoExtracted),
          )
          .normalizedForLibraryStorage();

      await _fileStorage.overwriteBundleFile(filePath, updatedVibes);

      final previews = updatedVibes
          .where((v) => v.thumbnail != null)
          .take(4)
          .map((v) => v.thumbnail!)
          .toList();
      final updatedEntry = entry.copyWith(
        bundledVibeNames: updatedVibes
            .map((v) => v.displayName)
            .toList(growable: false),
        bundledVibePreviews: previews.isEmpty ? null : previews,
        bundledVibeEncodings: updatedVibes
            .map((v) => v.vibeEncoding)
            .toList(growable: false),
        bundledVibeStrengths: updatedVibes
            .map((v) => v.strength)
            .toList(growable: false),
        bundledVibeInfoExtracted: updatedVibes
            .map((v) => v.infoExtracted)
            .toList(growable: false),
      );

      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      await _deleteDisplayThumbnailCache(updatedEntry.id);
      return await getEntry(updatedEntry.id) ?? updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save bundle child params', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 保存 Bundle 条目（新增或更新）
  Future<VibeLibraryEntry> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) async {
    try {
      if (vibes.isEmpty) throw ArgumentError('vibes cannot be empty');

      final existingPath = replaceEntry?.filePath;
      final canOverwriteExistingBundle =
          existingPath != null &&
          existingPath.isNotEmpty &&
          p.extension(existingPath).toLowerCase() == '.naiv4vibebundle' &&
          await File(existingPath).exists();
      late final String filePath;
      if (canOverwriteExistingBundle) {
        filePath = existingPath;
        await _fileStorage.overwriteBundleFile(filePath, vibes);
      } else {
        filePath = await _fileStorage.saveBundleToFile(vibes, bundleName: name);
      }

      var entry = VibeLibraryEntry.fromVibeReference(
        name: p.basenameWithoutExtension(filePath),
        vibeData: vibes.first,
        categoryId: categoryId,
        tags: tags,
        filePath: filePath,
      );

      final existingEntry = replaceEntry;
      if (existingEntry != null) {
        entry = entry.copyWith(
          id: existingEntry.id,
          isFavorite: existingEntry.isFavorite,
          usedCount: existingEntry.usedCount,
          lastUsedAt: existingEntry.lastUsedAt,
          createdAt: existingEntry.createdAt,
        );
      }

      entry = entry.copyWith(
        bundleId: p.basenameWithoutExtension(filePath),
        bundledVibeNames: vibes.map((v) => v.displayName).toList(),
        bundledVibePreviews: () {
          final previews = vibes
              .where((v) => v.thumbnail != null)
              .take(4)
              .map((v) => v.thumbnail!)
              .toList();
          return previews.isEmpty ? null : previews;
        }(),
        bundledVibeEncodings: vibes.map((v) => v.vibeEncoding).toList(),
        bundledVibeStrengths: vibes.map((v) => v.strength).toList(),
        bundledVibeInfoExtracted: vibes.map((v) => v.infoExtracted).toList(),
      );

      await _putStoredEntry(entry);
      await _upsertDisplayEntryIfReady(entry);
      await _deleteDisplayThumbnailCache(entry.id);
      AppLogger.d('Bundle entry saved: ${entry.displayName}', _tag);
      return entry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save bundle entry', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 根据 ID 获取条目
  Future<VibeLibraryEntry?> getEntry(String id) async {
    final span = VibePerformanceDiagnostics.start(
      'storage.getEntry',
      details: {'id': id},
    );
    var found = false;
    var hasFile = false;
    var fileLoaded = false;
    var fileMissing = false;
    var isBundle = false;
    var previewsLoaded = false;
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;
      found = true;
      isBundle = entry.isBundle;

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) return entry;
      hasFile = true;

      final vibeData = await _fileStorage.loadVibeFromFile(filePath);
      if (vibeData == null) {
        fileMissing = true;
        AppLogger.w('Entry file missing or invalid: $filePath', _tag);
        return null;
      }
      fileLoaded = true;

      // 旧库里存在“文件只保存编码，原图仍只留在 Hive 条目里”的情况。
      // 回读文件时要保住这份原图来源，否则条目会意外失去重新编码能力。
      // 也兼容曾经错误写成 type=image、但 Hive 条目里仍有 encoding 的文件。
      final effectiveThumbnail =
          vibeData.thumbnail ?? entry.vibeThumbnail ?? entry.thumbnail;
      final effectiveRawImageData = vibeData.rawImageData ?? entry.rawImageData;
      final effectiveVibeEncoding = vibeData.vibeEncoding.isNotEmpty
          ? vibeData.vibeEncoding
          : entry.vibeEncoding;
      var mergedEntry = entry
          .updateVibeData(
            vibeData.copyWith(
              vibeEncoding: effectiveVibeEncoding,
              thumbnail: effectiveThumbnail,
              rawImageData: effectiveRawImageData,
            ),
          )
          .copyWith(filePath: filePath);
      if (entry.isBundle) {
        final bundleVibes = await _fileStorage.extractVibesFromBundle(filePath);
        if (bundleVibes.isNotEmpty) {
          mergedEntry = mergedEntry.copyWith(
            bundledVibeNames: bundleVibes
                .map((v) => v.displayName)
                .toList(growable: false),
            bundledVibeEncodings: bundleVibes
                .map((v) => v.vibeEncoding)
                .toList(growable: false),
            bundledVibeStrengths: bundleVibes
                .map((v) => v.strength)
                .toList(growable: false),
            bundledVibeInfoExtracted: bundleVibes
                .map((v) => v.infoExtracted)
                .toList(growable: false),
          );
        }

        final previews = await _fileStorage.extractPreviewsFromBundle(filePath);
        if (previews.isNotEmpty) {
          previewsLoaded = true;
          mergedEntry = mergedEntry.copyWith(bundledVibePreviews: previews);
        }
      }

      return mergedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get entry', e, stackTrace, _tag);
      return null;
    } finally {
      span.finish(
        details: {
          'found': found,
          'hasFile': hasFile,
          'fileLoaded': fileLoaded,
          'fileMissing': fileMissing,
          'isBundle': isBundle,
          'previewsLoaded': previewsLoaded,
        },
      );
    }
  }

  /// 读取 bundle 条目中的指定子 Vibe。
  Future<VibeReference?> loadBundleChildVibe(String id, int childIndex) async {
    if (childIndex < 0) return null;

    try {
      final entry = await _readStoredEntry(id);
      if (entry == null || !entry.isBundle) return null;

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) return null;

      return await _fileStorage.extractVibeFromBundle(filePath, childIndex);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load bundle child vibe', e, stackTrace, _tag);
      return null;
    }
  }

  /// 获取所有条目
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    return VibePerformanceDiagnostics.measure(
      'storage.getAllEntries',
      () async {
        await _ensureInit();
        try {
          final entries = _entriesBox!.values.toList(growable: false);
          return Future.wait(entries.map(_resolveEntryDisplayParams));
        } catch (e, stackTrace) {
          AppLogger.e(
            'Failed to get all entries: $e',
            'VibeLibrary',
            stackTrace,
          );
          return [];
        }
      },
      resultDetails: (entries) => {'entries': entries.length},
    );
  }

  /// 获取展示列表用的轻量条目。
  ///
  /// 该路径不会读取或解析每个 .naiv4vibe/.naiv4vibebundle 文件，也不会把
  /// vibeEncoding、rawImageData、bundle encodings 等重负载放进 UI 状态。
  /// 需要真正导入、导出、编辑时，再通过 getEntry(id) 按需读取完整数据。
  Future<List<VibeLibraryEntry>> getDisplayEntries() async {
    final span = VibePerformanceDiagnostics.start('storage.getDisplayEntries');
    var cacheReady = false;
    var rebuilt = false;
    var entryCount = 0;
    try {
      await _ensureDisplayEntriesBox();
      cacheReady = await _isDisplayCacheReady();
      if (cacheReady) {
        final entries = _displayEntriesBox!.values.toList(growable: false);
        entryCount = entries.length;
        return entries;
      }

      rebuilt = true;
      final entries = await _rebuildDisplayEntriesCache();
      entryCount = entries.length;
      return entries;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get display entries: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    } finally {
      span.finish(
        details: {
          'cacheReady': cacheReady,
          'rebuilt': rebuilt,
          'entries': entryCount,
        },
      );
    }
  }

  /// 根据分类 ID 获取条目
  Future<List<VibeLibraryEntry>> getEntriesByCategory(
    String? categoryId,
  ) async {
    final entries = await getAllEntries();
    return entries.where((entry) => entry.categoryId == categoryId).toList();
  }

  Future<VibeLibraryEntry> _resolveEntryDisplayParams(
    VibeLibraryEntry entry,
  ) async {
    final filePath = entry.filePath;
    if (filePath == null || filePath.isEmpty) {
      return entry;
    }

    final storedParams = await _fileStorage.loadImportParams(filePath);
    if (storedParams == null) {
      return entry;
    }

    if (entry.strength == storedParams.strength &&
        entry.infoExtracted == storedParams.infoExtracted) {
      return entry;
    }

    return entry.copyWith(
      strength: storedParams.strength,
      infoExtracted: storedParams.infoExtracted,
    );
  }

  /// 删除条目
  ///
  /// 注意：即使文件删除失败，也会删除 Hive 条目以保持数据一致性。
  /// 文件删除失败会被记录但不会阻止条目删除。
  Future<bool> deleteEntry(String id) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return false;

      final filePath = entry.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        final fileDeleted = await _fileStorage.deleteVibeFile(filePath);
        if (!fileDeleted) {
          AppLogger.w(
            'File delete failed but continuing to delete Hive entry: $id',
            _tag,
          );
          // 不返回 false，继续删除 Hive 条目以保持数据一致性
        }
      }

      await _deleteStoredEntry(id);
      await _deleteDisplayEntryIfReady(id);
      await _deleteDisplayThumbnailCache(id);
      AppLogger.d('Entry deleted: $id', _tag);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entry', e, stackTrace, _tag);
      return false;
    }
  }

  /// 批量删除条目
  Future<int> deleteEntries(List<String> ids) async {
    var deletedCount = 0;
    try {
      for (final id in ids) {
        final deleted = await deleteEntry(id);
        if (deleted) {
          deletedCount++;
        }
      }
      AppLogger.d('Entries deleted: $deletedCount', _tag);
      return deletedCount;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entries', e, stackTrace, _tag);
      return deletedCount;
    }
  }

  /// 搜索条目
  Future<List<VibeLibraryEntry>> searchEntries(String query) async {
    await _ensureInit();
    try {
      final allEntries = _entriesBox!.values.toList();
      if (query.isEmpty) return allEntries;

      final lowerQuery = query.toLowerCase();
      return allEntries.where((entry) {
        return entry.name.toLowerCase().contains(lowerQuery) ||
            entry.vibeDisplayName.toLowerCase().contains(lowerQuery) ||
            entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to search entries: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取收藏的条目
  Future<List<VibeLibraryEntry>> getFavoriteEntries() async {
    await _ensureInit();
    try {
      return _entriesBox!.values.where((entry) => entry.isFavorite).toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get favorite entries: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }

  /// 获取最近使用的条目（按最后使用时间排序）
  Future<List<VibeLibraryEntry>> getRecentEntries({int limit = 20}) async {
    try {
      await _ensureInit();
      final entries = _entriesBox!.values
          .where((entry) => entry.lastUsedAt != null)
          .toList();
      entries.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
      return entries.take(limit).toList();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get recent entries', e, stackTrace, _tag);
      return [];
    }
  }

  /// 获取最近使用的轻量展示条目（按最后使用时间排序）。
  ///
  /// 用于生成页/画布的最近列表，避免仅为了展示最近项就打开完整条目 Box。
  Future<List<VibeLibraryEntry>> getRecentDisplayEntries({
    int limit = 20,
  }) async {
    return VibePerformanceDiagnostics.measure(
      'storage.getRecentDisplayEntries',
      () async {
        final entries = await getDisplayEntries();
        final recentEntries = entries
            .where((entry) => entry.lastUsedAt != null)
            .toList(growable: false);
        recentEntries.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
        return recentEntries.take(limit).toList(growable: false);
      },
      details: {'limit': limit},
      resultDetails: (entries) => {'entries': entries.length},
    );
  }

  /// 增加使用次数
  Future<VibeLibraryEntry?> incrementUsedCount(String id) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = entry.recordUsage();
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d(
        'Entry usage incremented: ${entry.displayName}',
        'VibeLibrary',
      );
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to increment used count: $e',
        'VibeLibrary',
        stackTrace,
      );
      return null;
    }
  }

  /// 切换收藏状态
  Future<VibeLibraryEntry?> toggleFavorite(String id) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = entry.toggleFavorite();
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d(
        'Entry favorite toggled: ${entry.displayName}',
        'VibeLibrary',
      );
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to toggle favorite: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 更新条目分类
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(categoryId: categoryId);
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d(
        'Entry category updated: ${entry.displayName}',
        'VibeLibrary',
      );
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update entry category: $e',
        'VibeLibrary',
        stackTrace,
      );
      return null;
    }
  }

  /// 更新条目标签
  Future<VibeLibraryEntry?> updateEntryTags(
    String id,
    List<String> tags,
  ) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(tags: tags);
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d('Entry tags updated: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update entry tags: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 更新条目缩略图
  Future<VibeLibraryEntry?> updateEntryThumbnail(
    String id,
    Uint8List? thumbnail,
  ) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(thumbnail: thumbnail);
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      await _deleteDisplayThumbnailCache(id);
      AppLogger.d(
        'Entry thumbnail updated: ${entry.displayName}',
        'VibeLibrary',
      );
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update entry thumbnail: $e',
        'VibeLibrary',
        stackTrace,
      );
      return null;
    }
  }

  /// 获取条目数量
  Future<int> getEntriesCount() async {
    await _ensureInit();
    try {
      return _entriesBox!.length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get entries count: $e', 'VibeLibrary', stackTrace);
      return 0;
    }
  }

  /// 获取指定分类的条目数量
  Future<int> getEntriesCountByCategory(String? categoryId) async {
    await _ensureInit();
    try {
      return _entriesBox!.values
          .where((entry) => entry.categoryId == categoryId)
          .length;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get entries count by category: $e',
        'VibeLibrary',
        stackTrace,
      );
      return 0;
    }
  }

  /// 检查条目是否存在
  Future<bool> entryExists(String id) async {
    try {
      if (_entriesBox != null && _entriesBox!.isOpen) {
        return _entriesBox!.containsKey(id);
      }

      await _ensureLazyEntriesBox();
      return _lazyEntriesBox!.containsKey(id);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to check entry existence: $e',
        'VibeLibrary',
        stackTrace,
      );
      return false;
    }
  }

  /// 清除所有条目
  Future<void> clearAllEntries() async {
    try {
      await _clearStoredEntries();
      await _ensureDisplayEntriesBox();
      await _displayEntriesBox!.clear();
      await _ensureThumbnailCacheBox();
      await _thumbnailCacheBox!.clear();
      await _setDisplayCacheReady(true);
      AppLogger.i('All entries cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to clear all entries: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  /// 扫描文件夹并同步到 Hive
  Future<VibeFolderSyncResult> syncWithFileSystem({
    bool removeMissingEntries = true,
  }) async {
    final span = VibePerformanceDiagnostics.start(
      'storage.syncWithFileSystem',
      details: {'removeMissingEntries': removeMissingEntries},
    );
    VibeFolderSyncResult? syncResult;
    try {
      await _ensureInit();
      final existingEntries = _entriesBox!.values.toList(growable: false);

      final result = await _fileStorage.syncFolderToHive(
        existingEntries: existingEntries,
        onUpsertEntry: (entry) async {
          await _entriesBox!.put(entry.id, entry);
          await _upsertDisplayEntryIfReady(entry);
          await _deleteDisplayThumbnailCache(entry.id);
        },
        onDeleteEntry: removeMissingEntries
            ? (entry) async {
                await _entriesBox!.delete(entry.id);
                await _deleteDisplayEntryIfReady(entry.id);
                await _deleteDisplayThumbnailCache(entry.id);
              }
            : null,
      );
      syncResult = result;

      AppLogger.i(
        'File system sync completed: scanned=${result.scannedCount}, '
        'upserted=${result.upsertedCount}, deleted=${result.deletedCount}, '
        'failed=${result.failedCount}',
        _tag,
      );
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to sync with file system', e, stackTrace, _tag);
      return VibeFolderSyncResult(
        scannedCount: 0,
        upsertedCount: 0,
        deletedCount: 0,
        failedCount: 1,
        errors: [e.toString()],
      );
    } finally {
      span.finish(
        details: {
          'scanned': syncResult?.scannedCount,
          'upserted': syncResult?.upsertedCount,
          'deleted': syncResult?.deletedCount,
          'failed': syncResult?.failedCount,
        },
      );
    }
  }

  /// 重命名条目文件并更新路径
  Future<VibeLibraryEntry?> updateEntryFile(String id, String newName) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) {
        return null;
      }

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) {
        AppLogger.w('Skip renaming entry without filePath: $id', _tag);
        return null;
      }

      final renamedPath = await _fileStorage.renameVibeFile(filePath, newName);
      if (renamedPath == null) {
        return null;
      }

      final updatedEntry = entry.copyWith(
        name: newName.trim(),
        filePath: renamedPath,
      );
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d('Entry file renamed: $filePath -> $renamedPath', _tag);
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update entry file', e, stackTrace, _tag);
      return null;
    }
  }

  /// 重命名条目名称，并同步重命名文件后更新条目路径
  Future<VibeEntryRenameResult> renameEntry(
    String entryId,
    String newName,
  ) async {
    try {
      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) {
        return const VibeEntryRenameResult.failure(
          VibeEntryRenameError.invalidName,
        );
      }

      final entry = await _readStoredEntry(entryId);
      if (entry == null) {
        return const VibeEntryRenameResult.failure(
          VibeEntryRenameError.entryNotFound,
        );
      }

      var hasConflict = false;
      await _forEachStoredEntryLazily((candidate) async {
        if (candidate.id != entryId &&
            candidate.name.trim().toLowerCase() == trimmedName.toLowerCase()) {
          hasConflict = true;
        }
      });
      if (hasConflict) {
        return const VibeEntryRenameResult.failure(
          VibeEntryRenameError.nameConflict,
        );
      }

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) {
        return const VibeEntryRenameResult.failure(
          VibeEntryRenameError.filePathMissing,
        );
      }

      final renamedPath = await _fileStorage.renameVibeFile(
        filePath,
        trimmedName,
      );
      if (renamedPath == null) {
        return const VibeEntryRenameResult.failure(
          VibeEntryRenameError.fileRenameFailed,
        );
      }

      final updatedEntry = entry.copyWith(
        name: trimmedName,
        filePath: renamedPath,
      );
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d('Entry renamed: $filePath -> $renamedPath', _tag);
      return VibeEntryRenameResult.success(updatedEntry);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to rename entry', e, stackTrace, _tag);
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.fileRenameFailed,
      );
    }
  }

  /// 更新 bundle 预览缓存
  Future<VibeLibraryEntry?> updateEntryPreviews(
    String id, {
    int maxCount = 4,
  }) async {
    try {
      final entry = await _readStoredEntry(id);
      if (entry == null) {
        return null;
      }

      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty || !entry.isBundle) {
        return entry;
      }

      final previews = await _fileStorage.extractPreviewsFromBundle(
        filePath,
        maxCount: maxCount,
      );
      final updatedEntry = entry.copyWith(bundledVibePreviews: previews);
      await _putStoredEntry(updatedEntry);
      await _upsertDisplayEntryIfReady(updatedEntry);
      AppLogger.d('Entry previews updated: ${entry.displayName}', _tag);
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update entry previews', e, stackTrace, _tag);
      return null;
    }
  }

  Future<VibeLibraryEntry> _saveEntryFile(VibeLibraryEntry entry) async {
    try {
      final vibeData = entry.toVibeReference();
      final savedPath = entry.isBundle
          ? await _fileStorage.saveBundleToFile(
              _buildBundleVibeReferences(entry),
              bundleName: entry.name,
            )
          : await _fileStorage.saveVibeToFile(vibeData, customName: entry.name);

      if (savedPath.isEmpty) {
        throw StateError('Saved vibe file path is empty');
      }

      // 从实际保存的文件路径提取文件名（不含扩展名），确保 name 与文件名一致
      final actualFileName = p.basenameWithoutExtension(savedPath);

      return entry.copyWith(filePath: savedPath, name: actualFileName);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save entry file', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 构建 bundle 中所有 vibes 的 VibeReference 列表
  List<VibeReference> _buildBundleVibeReferences(VibeLibraryEntry entry) {
    final encodings = entry.bundledVibeEncodings;
    final names = entry.bundledVibeNames;
    final previews = entry.bundledVibePreviews;
    final strengths = entry.bundledVibeStrengths;
    final infoExtracted = entry.bundledVibeInfoExtracted;

    if (encodings == null || encodings.isEmpty) {
      // 如果没有存储编码列表，只返回第一个 vibe
      return [entry.toVibeReference()];
    }

    final results = <VibeReference>[];
    for (var i = 0; i < encodings.length; i++) {
      final encoding = encodings[i];
      final name = names != null && i < names.length
          ? names[i]
          : '${entry.name}#$i';
      final thumbnail = previews != null && i < previews.length
          ? previews[i]
          : null;
      final strength = strengths != null && i < strengths.length
          ? strengths[i]
          : entry.strength;
      final info = infoExtracted != null && i < infoExtracted.length
          ? infoExtracted[i]
          : entry.infoExtracted;

      results.add(
        VibeReference(
          displayName: name,
          vibeEncoding: encoding,
          thumbnail: thumbnail,
          strength: strength,
          infoExtracted: info,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
      );
    }

    return results;
  }

  // ==================== Generation State Persistence ====================

  static const String _generationStateKey = 'generation_state';
  static const String _generationStateFileName = 'generation_state.json';
  String? _generationStateFilePath;

  Future<File?> _resolveGenerationStateFile({
    required bool createDirectory,
  }) async {
    try {
      final cachedPath = _generationStateFilePath;
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (createDirectory) {
          await file.parent.create(recursive: true);
        }
        return file;
      }

      final appDir = await getApplicationSupportDirectory();
      final dir = Directory(p.join(appDir.path, 'generation_state'));
      if (createDirectory) {
        await dir.create(recursive: true);
      }

      final file = File(p.join(dir.path, _generationStateFileName));
      _generationStateFilePath = file.path;
      return file;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to resolve generation state file, falling back to SharedPreferences',
        e,
        stackTrace,
        _tag,
      );
      return null;
    }
  }

  /// 保存生成参数中的 Vibe 和精准参考状态
  Future<void> saveGenerationState({
    required List<Map<String, dynamic>> vibeReferences,
    required List<Map<String, dynamic>> preciseReferences,
    required bool normalizeVibeStrength,
  }) async {
    try {
      final stateData = {
        'vibeReferences': vibeReferences,
        'preciseReferences': preciseReferences,
        'normalizeVibeStrength': normalizeVibeStrength,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await saveGenerationStateJson(jsonEncode(stateData));
      AppLogger.d(
        'Generation state saved: ${vibeReferences.length} vibes, ${preciseReferences.length} precise refs',
        'VibeLibrary',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to save generation state',
        e,
        stackTrace,
        'VibeLibrary',
      );
    }
  }

  /// 保存已序列化的生成状态。
  ///
  /// 生成状态可能包含多张 Vibe/Precise Reference 图片。独立文件比
  /// SharedPreferences 更适合承载这类较大 payload，旧 SharedPreferences
  /// 键仍保留为读取兼容 fallback。
  Future<void> saveGenerationStateJson(String stateJson) async {
    final span = VibePerformanceDiagnostics.start(
      'storage.saveGenerationStateJson',
      details: {'chars': stateJson.length},
    );
    var target = 'none';
    try {
      final file = await _resolveGenerationStateFile(createDirectory: true);
      if (file != null) {
        try {
          await file.writeAsString(stateJson);
          target = 'file';
          unawaited(_removeLegacyGenerationStatePreference());
          AppLogger.d('Generation state JSON saved to file', 'VibeLibrary');
          return;
        } catch (e, stackTrace) {
          AppLogger.e(
            'Failed to write generation state file, falling back to SharedPreferences',
            e,
            stackTrace,
            'VibeLibrary',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_generationStateKey, stateJson);
      target = 'sharedPreferences';
      AppLogger.d(
        'Generation state JSON saved to SharedPreferences',
        'VibeLibrary',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to save generation state JSON',
        e,
        stackTrace,
        'VibeLibrary',
      );
    } finally {
      span.finish(details: {'target': target});
    }
  }

  /// 加载生成参数状态
  Future<Map<String, dynamic>?> loadGenerationState() async {
    try {
      final jsonString = await loadGenerationStateJson();
      if (jsonString != null) {
        final stateData = jsonDecode(jsonString) as Map<String, dynamic>;
        AppLogger.d('Generation state loaded', 'VibeLibrary');
        return stateData;
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load generation state',
        e,
        stackTrace,
        'VibeLibrary',
      );
      return null;
    }
  }

  /// 加载已序列化的生成状态。
  Future<String?> loadGenerationStateJson() async {
    final span = VibePerformanceDiagnostics.start(
      'storage.loadGenerationStateJson',
    );
    var source = 'missing';
    var chars = 0;
    try {
      final file = await _resolveGenerationStateFile(createDirectory: false);
      if (file != null) {
        try {
          if (await file.exists()) {
            final jsonString = await file.readAsString();
            source = 'file';
            chars = jsonString.length;
            AppLogger.d(
              'Generation state JSON loaded from file',
              'VibeLibrary',
            );
            return jsonString;
          }
        } catch (e, stackTrace) {
          AppLogger.e(
            'Failed to read generation state file, falling back to SharedPreferences',
            e,
            stackTrace,
            'VibeLibrary',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_generationStateKey);
      if (jsonString != null) {
        source = 'sharedPreferences';
        chars = jsonString.length;
        AppLogger.d(
          'Generation state JSON loaded from SharedPreferences',
          'VibeLibrary',
        );
      }
      return jsonString;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load generation state JSON',
        e,
        stackTrace,
        'VibeLibrary',
      );
      return null;
    } finally {
      span.finish(details: {'source': source, 'chars': chars});
    }
  }

  Future<void> _removeLegacyGenerationStatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_generationStateKey)) {
        await prefs.remove(_generationStateKey);
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to remove legacy generation state preference',
        e,
        stackTrace,
        'VibeLibrary',
      );
    }
  }

  /// 清除保存的生成状态
  Future<void> clearGenerationState() async {
    try {
      final file = await _resolveGenerationStateFile(createDirectory: false);
      if (file != null && await file.exists()) {
        await file.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_generationStateKey);
      AppLogger.d('Generation state cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to clear generation state: $e',
        'VibeLibrary',
        stackTrace,
      );
    }
  }
}

/// Provider
@Riverpod(keepAlive: true)
VibeLibraryStorageService vibeLibraryStorageService(Ref ref) {
  return VibeLibraryStorageService(fileStorage: VibeFileStorageService());
}
