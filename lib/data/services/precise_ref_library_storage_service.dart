import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums/precise_ref_type.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/display_thumbnail_utils.dart';
import '../../core/utils/precise_ref_library_path_helper.dart';
import '../models/precise_ref/precise_ref_library_entry.dart';
import 'precise_ref_portable_importer.dart';

export 'precise_ref_portable_importer.dart'
    show InvalidPreciseRefImageException, PreciseRefLibraryFileSystem;

part 'precise_ref_library_storage_service.g.dart';

/// 精准参考库存储服务
///
/// 原图以独立文件落盘，Hive 保存轻量元数据与按需读取的展示缩略图缓存。
class PreciseRefLibraryStorageService {
  PreciseRefLibraryStorageService({
    String? overrideDirectory,
    PreciseRefLibraryFileSystem fileSystem =
        const PreciseRefLibraryFileSystem(),
  }) : _overrideDirectory = overrideDirectory,
       _fileSystem = fileSystem;

  static const String _entriesBoxName = 'precise_ref_library_entries';
  static const String _thumbnailCacheBoxName =
      'precise_ref_library_thumbnails_v1';
  static const String _importingMarker = '.importing-';
  static const String _deletingMarker = '.deleting-';
  static const String _tag = 'PreciseRefLibrary';
  static final RegExp _managedImageFileName = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(png|jpe?g|webp|gif|bmp)$',
    caseSensitive: false,
  );

  final String? _overrideDirectory;
  final PreciseRefLibraryFileSystem _fileSystem;
  Box<PreciseRefLibraryEntry>? _entriesBox;
  LazyBox<Uint8List>? _thumbnailCacheBox;
  Future<void>? _initFuture;
  final Map<String, Future<Uint8List?>> _thumbnailLoadsById = {};
  final Set<String> _deletingIds = {};

  /// 初始化（注册 Adapter、打开 box 并修复中断操作留下的暂存文件）。
  Future<void> init() {
    return _initFuture ??= _doInit().catchError((Object e, StackTrace s) {
      _initFuture = null;
      AppLogger.e('精准参考库存储初始化失败', e, s, _tag);
      throw e;
    });
  }

  Future<void> _doInit() async {
    if (!Hive.isAdapterRegistered(26)) {
      Hive.registerAdapter(PreciseRefLibraryEntryAdapter());
    }
    _entriesBox ??= await Hive.openBox<PreciseRefLibraryEntry>(_entriesBoxName);
    _thumbnailCacheBox ??= await Hive.openLazyBox<Uint8List>(
      _thumbnailCacheBoxName,
    );
    await _reconcileStorage();
  }

  /// 获取原图保存目录（确保存在）。
  Future<String> _resolveImageDirectory() async {
    final dir =
        _overrideDirectory ??
        await PreciseRefLibraryPathHelper.instance.getDefaultPath();
    await PreciseRefLibraryPathHelper.instance.ensurePathExists(dir);
    return dir;
  }

  /// 按字节魔数检测受支持的图片扩展名。
  static String detectImageExtension(Uint8List bytes) =>
      PreciseRefImageCodec.detectExtension(bytes);

  /// 获取全部条目。
  Future<List<PreciseRefLibraryEntry>> getAllEntries() async {
    await init();
    return _entriesBox!.values.toList();
  }

  /// 从图片字节导入新条目。
  ///
  /// 图片先写入带 importing 标记的暂存文件。元数据持久化成功后再原子重命名，
  /// 启动对账可以恢复进程中断留下的任一阶段。
  Future<PreciseRefLibraryEntry> importFromBytes(
    Uint8List bytes, {
    required String name,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
  }) async {
    await init();
    final extension = detectImageExtension(bytes);
    final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
    if (thumbnail == null || thumbnail.isEmpty) {
      throw const InvalidPreciseRefImageException();
    }

    final dir = await _resolveImageDirectory();
    final id = const Uuid().v4();
    final filePath = p.join(dir, '$id$extension');
    final stagingPath =
        '$filePath$_importingMarker${DateTime.now().microsecondsSinceEpoch}';
    final entry = PreciseRefLibraryEntry.create(
      id: id,
      name: name,
      imagePath: filePath,
      type: type,
      strength: strength,
      fidelity: fidelity,
    );

    var metadataWritten = false;
    try {
      await _fileSystem.writeBytes(stagingPath, bytes);
      await _entriesBox!.put(id, entry);
      metadataWritten = true;
      await _fileSystem.rename(stagingPath, filePath);
    } catch (e, s) {
      var metadataRolledBack = !metadataWritten;
      if (metadataWritten) {
        try {
          await _entriesBox!.delete(id);
          metadataRolledBack = true;
        } catch (rollbackError, rollbackStack) {
          AppLogger.e('回滚精准参考元数据失败', rollbackError, rollbackStack, _tag);
        }
      }
      if (metadataRolledBack) {
        await _deleteIfExists(stagingPath);
      }
      AppLogger.e('精准参考入库失败', e, s, _tag);
      rethrow;
    }

    try {
      await _thumbnailCacheBox!.put(id, thumbnail);
    } catch (e) {
      AppLogger.w('保存精准参考缩略图失败: $e', _tag);
    }

    AppLogger.i('精准参考入库: ${entry.name} ($id)', _tag);
    return entry;
  }

  /// Imports a portable record with stable identity and transactional rollback.
  Future<PreciseRefLibraryEntry> importPortableEntry(
    Uint8List bytes, {
    required String id,
    required String name,
    required PreciseRefType type,
    required double strength,
    required double fidelity,
    required bool isFavorite,
    required int usedCount,
    required DateTime? lastUsedAt,
    required DateTime createdAt,
  }) async {
    return importPortableEntryStream(
      Stream.value(bytes),
      expectedLength: bytes.length,
      id: id,
      name: name,
      type: type,
      strength: strength,
      fidelity: fidelity,
      isFavorite: isFavorite,
      usedCount: usedCount,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }

  Future<PreciseRefLibraryEntry> importPortableEntryStream(
    Stream<List<int>> bytes, {
    required int expectedLength,
    required String id,
    required String name,
    required PreciseRefType type,
    required double strength,
    required double fidelity,
    required bool isFavorite,
    required int usedCount,
    required DateTime? lastUsedAt,
    required DateTime createdAt,
  }) async {
    await init();
    if (!_managedImageFileName.hasMatch('$id.png')) {
      throw const FormatException('Invalid precise reference stable ID');
    }
    return PreciseRefPortableImporter(
      entries: _entriesBox!,
      thumbnails: _thumbnailCacheBox!,
      fileSystem: _fileSystem,
    ).import(
      bytes: bytes,
      expectedLength: expectedLength,
      directory: await _resolveImageDirectory(),
      id: id,
      name: name,
      type: type,
      strength: strength,
      fidelity: fidelity,
      isFavorite: isFavorite,
      usedCount: usedCount,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }

  /// 更新条目元数据（不触碰磁盘文件）。
  Future<PreciseRefLibraryEntry?> updateEntry(
    String id, {
    String? name,
    PreciseRefType? type,
    double? strength,
    double? fidelity,
  }) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;

    final trimmedName = name?.trim();
    final updated = entry.copyWith(
      name: (trimmedName == null || trimmedName.isEmpty)
          ? entry.name
          : trimmedName,
      typeIndex: type?.index ?? entry.typeIndex,
      strength: strength ?? entry.strength,
      fidelity: fidelity ?? entry.fidelity,
    );
    await _entriesBox!.put(id, updated);
    return updated;
  }

  /// 删除条目（元数据 + 缩略图缓存 + 磁盘文件）。
  ///
  /// 原图先重命名为 deleting 暂存文件；若元数据删除失败则立即恢复。
  /// 进程中断时，启动对账会根据元数据是否仍存在决定恢复或清理暂存文件。
  Future<bool> deleteEntry(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return false;

    _deletingIds.add(id);
    String? tombstonePath;
    try {
      if (await _fileSystem.exists(entry.imagePath)) {
        tombstonePath =
            '${entry.imagePath}$_deletingMarker'
            '${DateTime.now().microsecondsSinceEpoch}';
        try {
          await _fileSystem.rename(entry.imagePath, tombstonePath);
        } catch (e, s) {
          AppLogger.e('暂存待删除精准参考原图失败', e, s, _tag);
          return false;
        }
      }

      try {
        await _entriesBox!.delete(id);
      } catch (e, s) {
        await _restoreStagedFile(entry.imagePath, tombstonePath);
        AppLogger.e('删除精准参考元数据失败', e, s, _tag);
        rethrow;
      }

      try {
        await _thumbnailCacheBox!.delete(id);
      } catch (e) {
        AppLogger.w('删除精准参考缩略图缓存失败: $e', _tag);
      }
      if (tombstonePath != null) {
        await _deleteIfExists(tombstonePath);
      }
      return true;
    } finally {
      _deletingIds.remove(id);
    }
  }

  /// 切换收藏状态。
  Future<PreciseRefLibraryEntry?> toggleFavorite(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    final updated = entry.toggleFavorite();
    await _entriesBox!.put(id, updated);
    return updated;
  }

  /// 记录一次使用。
  Future<PreciseRefLibraryEntry?> recordUsage(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    final updated = entry.recordUsage();
    await _entriesBox!.put(id, updated);
    return updated;
  }

  /// 获取展示缩略图（LazyBox 缓存优先，未命中时生成并回写）。
  Future<Uint8List?> getDisplayThumbnail(String id) async {
    try {
      await init();
      if (_deletingIds.contains(id)) return null;

      final cached = await _thumbnailCacheBox!.get(id);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      final activeLoad = _thumbnailLoadsById[id];
      if (activeLoad != null) return activeLoad;

      final load = _loadAndCacheDisplayThumbnail(id);
      _thumbnailLoadsById[id] = load;
      try {
        return await load;
      } finally {
        if (identical(_thumbnailLoadsById[id], load)) {
          _thumbnailLoadsById.remove(id);
        }
      }
    } catch (e, s) {
      AppLogger.e('加载精准参考缩略图失败', e, s, _tag);
      return null;
    }
  }

  Future<Uint8List?> _loadAndCacheDisplayThumbnail(String id) async {
    if (_deletingIds.contains(id)) return null;
    final bytes = await readImageBytes(id);
    if (bytes == null) return null;
    final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
    if (thumbnail == null || thumbnail.isEmpty) return null;
    if (_deletingIds.contains(id) || _entriesBox!.get(id) == null) {
      return null;
    }
    await _thumbnailCacheBox!.put(id, thumbnail);
    return thumbnail;
  }

  /// 读取原图字节（文件丢失返回 null）。
  Future<Uint8List?> readImageBytes(String id) async {
    await init();
    if (_deletingIds.contains(id)) return null;
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    try {
      if (!await _fileSystem.exists(entry.imagePath)) {
        AppLogger.w('精准参考原图文件丢失: ${entry.imagePath}', _tag);
        return null;
      }
      return await _fileSystem.readBytes(entry.imagePath);
    } catch (e) {
      AppLogger.w('读取精准参考原图失败: $e', _tag);
      return null;
    }
  }

  Future<int?> getImageLength(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null || !await _fileSystem.exists(entry.imagePath)) {
      return null;
    }
    return _fileSystem.length(entry.imagePath);
  }

  Stream<List<int>> openImageRead(String id) async* {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null || !await _fileSystem.exists(entry.imagePath)) {
      throw StateError('Precise reference image is missing: $id');
    }
    yield* _fileSystem.openRead(entry.imagePath);
  }

  Future<void> _reconcileStorage() async {
    try {
      final directory = await _resolveImageDirectory();
      final entries = _entriesBox!.values.toList();
      final entryIds = entries.map((entry) => entry.id).toSet();
      final referencedPaths = entries
          .map((entry) => _pathKey(entry.imagePath))
          .toSet();

      final orphanCacheKeys = _thumbnailCacheBox!.keys
          .where((key) => key is! String || !entryIds.contains(key))
          .toList();
      if (orphanCacheKeys.isNotEmpty) {
        await _thumbnailCacheBox!.deleteAll(orphanCacheKeys);
      }

      await for (final entity in _fileSystem.list(directory)) {
        if (entity is! File) continue;
        await _reconcileFile(entity.path, referencedPaths);
      }
    } catch (e, s) {
      AppLogger.e('精准参考库存储对账失败', e, s, _tag);
    }
  }

  Future<void> _reconcileFile(
    String filePath,
    Set<String> referencedPaths,
  ) async {
    try {
      final markerIndex = _stagingMarkerIndex(filePath);
      if (markerIndex >= 0) {
        final originalPath = filePath.substring(0, markerIndex);
        final isReferenced = referencedPaths.contains(_pathKey(originalPath));
        final originalExists = await _fileSystem.exists(originalPath);
        if (isReferenced && !originalExists) {
          await _fileSystem.rename(filePath, originalPath);
        } else {
          await _fileSystem.delete(filePath);
        }
        return;
      }

      if (_managedImageFileName.hasMatch(p.basename(filePath)) &&
          !referencedPaths.contains(_pathKey(filePath))) {
        await _fileSystem.delete(filePath);
      }
    } catch (e) {
      AppLogger.w('清理精准参考孤立文件失败: $filePath ($e)', _tag);
    }
  }

  static int _stagingMarkerIndex(String filePath) {
    final importingIndex = filePath.lastIndexOf(_importingMarker);
    final deletingIndex = filePath.lastIndexOf(_deletingMarker);
    return importingIndex > deletingIndex ? importingIndex : deletingIndex;
  }

  static String _pathKey(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  Future<void> _restoreStagedFile(
    String originalPath,
    String? stagedPath,
  ) async {
    if (stagedPath == null ||
        !await _fileSystem.exists(stagedPath) ||
        await _fileSystem.exists(originalPath)) {
      return;
    }
    try {
      await _fileSystem.rename(stagedPath, originalPath);
    } catch (e, s) {
      AppLogger.e('恢复精准参考原图失败', e, s, _tag);
    }
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      if (await _fileSystem.exists(path)) {
        await _fileSystem.delete(path);
      }
    } catch (e) {
      AppLogger.w('清理精准参考暂存文件失败: $path ($e)', _tag);
    }
  }

  /// 关闭 box（测试用）。
  Future<void> close() async {
    await _entriesBox?.close();
    await _thumbnailCacheBox?.close();
    _entriesBox = null;
    _thumbnailCacheBox = null;
    _initFuture = null;
    _thumbnailLoadsById.clear();
    _deletingIds.clear();
  }
}

@Riverpod(keepAlive: true)
PreciseRefLibraryStorageService preciseRefLibraryStorageService(Ref ref) {
  return PreciseRefLibraryStorageService();
}
