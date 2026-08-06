import 'dart:async';
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

part 'precise_ref_library_storage_service.g.dart';

/// 精准参考库存储服务
///
/// 双层存储：原图以 {id}.png 等文件形式落盘，Hive 仅保存轻量元数据
/// 与展示缩略图缓存，避免大字节进 Hive 导致的性能问题。
class PreciseRefLibraryStorageService {
  PreciseRefLibraryStorageService({String? overrideDirectory})
    : _overrideDirectory = overrideDirectory;

  static const String _entriesBoxName = 'precise_ref_library_entries';
  static const String _thumbnailCacheBoxName =
      'precise_ref_library_thumbnails_v1';
  static const String _tag = 'PreciseRefLibrary';

  final String? _overrideDirectory;
  Box<PreciseRefLibraryEntry>? _entriesBox;
  Box<Uint8List>? _thumbnailCacheBox;
  Future<void>? _initFuture;
  final Map<String, Future<Uint8List?>> _thumbnailLoadsById = {};

  /// 初始化（注册 Adapter 并打开 box，幂等且并发安全）
  Future<void> init() {
    return _initFuture ??= _doInit().catchError((Object e, StackTrace s) {
      _initFuture = null;
      AppLogger.e('精准参考库存储初始化失败', _tag, s);
      throw e;
    });
  }

  Future<void> _doInit() async {
    if (!Hive.isAdapterRegistered(26)) {
      Hive.registerAdapter(PreciseRefLibraryEntryAdapter());
    }
    _entriesBox ??= await Hive.openBox<PreciseRefLibraryEntry>(_entriesBoxName);
    _thumbnailCacheBox ??= await Hive.openBox<Uint8List>(
      _thumbnailCacheBoxName,
    );
  }

  /// 获取原图保存目录（确保存在）
  Future<String> _resolveImageDirectory() async {
    final dir =
        _overrideDirectory ??
        await PreciseRefLibraryPathHelper.instance.getDefaultPath();
    await PreciseRefLibraryPathHelper.instance.ensurePathExists(dir);
    return dir;
  }

  /// 按字节魔数检测图片扩展名（未知格式回退 .png）
  static String detectImageExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return '.jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    return '.png';
  }

  /// 获取全部条目
  Future<List<PreciseRefLibraryEntry>> getAllEntries() async {
    await init();
    return _entriesBox!.values.toList();
  }

  /// 获取单个条目
  Future<PreciseRefLibraryEntry?> getEntry(String id) async {
    await init();
    return _entriesBox!.get(id);
  }

  /// 从图片字节导入新条目
  ///
  /// 原图写为 {目录}/{id}{扩展名}，生成展示缩略图并保存元数据。
  Future<PreciseRefLibraryEntry> importFromBytes(
    Uint8List bytes, {
    required String name,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
  }) async {
    await init();
    final dir = await _resolveImageDirectory();
    final id = const Uuid().v4();
    final filePath = p.join(dir, '$id${detectImageExtension(bytes)}');
    await File(filePath).writeAsBytes(bytes, flush: true);

    final trimmedName = name.trim();
    final entry = PreciseRefLibraryEntry(
      id: id,
      name: trimmedName.isEmpty ? id.substring(0, 8) : trimmedName,
      imagePath: filePath,
      typeIndex: type.index,
      strength: strength,
      fidelity: fidelity,
      createdAt: DateTime.now(),
    );
    await _entriesBox!.put(id, entry);

    try {
      final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
      if (thumbnail != null && thumbnail.isNotEmpty) {
        await _thumbnailCacheBox!.put(id, thumbnail);
      }
    } catch (e) {
      AppLogger.w('生成精准参考缩略图失败: $e', _tag);
    }

    AppLogger.i('精准参考入库: ${entry.name} ($id)', _tag);
    return entry;
  }

  /// 更新条目元数据（不触碰磁盘文件）
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

  /// 删除条目（元数据 + 缩略图缓存 + 磁盘文件）
  ///
  /// 磁盘文件删除失败（如被占用）仅记录警告，不阻塞条目移除。
  Future<bool> deleteEntry(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return false;

    await _entriesBox!.delete(id);
    await _thumbnailCacheBox!.delete(id);

    try {
      final file = File(entry.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.w('删除精准参考原图失败（条目已移除）: $e', _tag);
    }
    return true;
  }

  /// 切换收藏状态
  Future<PreciseRefLibraryEntry?> toggleFavorite(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    final updated = entry.toggleFavorite();
    await _entriesBox!.put(id, updated);
    return updated;
  }

  /// 记录一次使用
  Future<PreciseRefLibraryEntry?> recordUsage(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    final updated = entry.recordUsage();
    await _entriesBox!.put(id, updated);
    return updated;
  }

  /// 获取展示缩略图（缓存优先，未命中时读原图压缩并回写缓存）
  Future<Uint8List?> getDisplayThumbnail(String id) async {
    await init();
    final cached = _thumbnailCacheBox!.get(id);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return _thumbnailLoadsById.putIfAbsent(id, () async {
      try {
        final bytes = await readImageBytes(id);
        if (bytes == null) return null;
        final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
        if (thumbnail != null && thumbnail.isNotEmpty) {
          await _thumbnailCacheBox!.put(id, thumbnail);
        }
        return thumbnail;
      } catch (e) {
        AppLogger.w('加载精准参考缩略图失败: $e', _tag);
        return null;
      } finally {
        // 允许后续重试（成功时下次直接命中缓存）
        unawaited(
          Future<void>.delayed(Duration.zero).then((_) {
            _thumbnailLoadsById.remove(id);
          }),
        );
      }
    });
  }

  /// 读取原图字节（文件丢失返回 null）
  Future<Uint8List?> readImageBytes(String id) async {
    await init();
    final entry = _entriesBox!.get(id);
    if (entry == null) return null;
    try {
      final file = File(entry.imagePath);
      if (!await file.exists()) {
        AppLogger.w('精准参考原图文件丢失: ${entry.imagePath}', _tag);
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      AppLogger.w('读取精准参考原图失败: $e', _tag);
      return null;
    }
  }

  /// 关闭 box（测试用）
  Future<void> close() async {
    await _entriesBox?.close();
    await _thumbnailCacheBox?.close();
    _entriesBox = null;
    _thumbnailCacheBox = null;
    _initFuture = null;
    _thumbnailLoadsById.clear();
  }
}

@Riverpod(keepAlive: true)
PreciseRefLibraryStorageService preciseRefLibraryStorageService(Ref ref) {
  return PreciseRefLibraryStorageService();
}
