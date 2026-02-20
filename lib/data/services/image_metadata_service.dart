import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/nai_metadata_parser.dart';
import '../models/gallery/nai_image_metadata.dart';

/// 图像元数据服务
///
/// 统一的元数据解析服务入口，所有场景（主页、本地画廊、拖拽）都使用此服务。
///
/// 架构：
/// - 对外统一接口，内部自动处理缓存
/// - 使用 Hive 持久缓存（重启后仍然有效）
/// - 内存缓存作为加速层（实现细节，对调用方透明）
/// - 预加载队列支持批量后台解析
class ImageMetadataService {
  static final ImageMetadataService _instance = ImageMetadataService._internal();
  factory ImageMetadataService() => _instance;
  ImageMetadataService._internal();

  // ============================================================
  // 配置常量
  // ============================================================

  /// 内存缓存容量（加速层）
  static const int _memoryCacheCapacity = 500;

  /// 流式解析读取的前N字节数（50KB）
  static const int _streamBufferSize = 50 * 1024;

  /// 预加载并发数
  static const int _preloadConcurrency = 3;

  /// 预加载队列最大长度
  static const int _maxQueueSize = 100;

  // ============================================================
  // 状态
  // ============================================================

  /// Hive Box（持久缓存）
  Box<String>? _persistentBox;

  /// 内存缓存（path -> metadata）
  final _memoryCache = _LRUCache<String, NaiImageMetadata>(capacity: _memoryCacheCapacity);

  /// 正在解析中的任务（防止重复解析）
  final _pendingFutures = <String, Future<NaiImageMetadata?>>{};

  /// 文件解析信号量（标准优先级，后台批量处理）
  final _fileSemaphore = _Semaphore(3);

  /// 高优先级信号量（前台用户请求）
  /// 独立槽位确保用户操作不受后台队列影响
  final _highPrioritySemaphore = _Semaphore(2);

  /// 预加载队列
  final _preloadQueue = <_PreloadTask>[];
  final _processingTaskIds = <String>{};
  bool _isProcessingQueue = false;

  // ============================================================
  // 统计
  // ============================================================

  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _fastParseCount = 0;
  int _fallbackParseCount = 0;
  int _parseErrors = 0;
  int _preloadSuccessCount = 0;
  int _preloadErrorCount = 0;

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化服务（在应用启动时调用）
  Future<void> initialize() async {
    if (_persistentBox != null && _persistentBox!.isOpen) return;

    try {
      // 检查 Box 是否已被其他代码打开
      if (Hive.isBoxOpen(StorageKeys.localMetadataCacheBox)) {
        _persistentBox = Hive.box<String>(StorageKeys.localMetadataCacheBox);
      } else {
        _persistentBox = await Hive.openBox<String>(StorageKeys.localMetadataCacheBox);
      }
      AppLogger.i(
        'ImageMetadataService initialized: persistent cache has ${_persistentBox!.length} entries',
        'ImageMetadataService',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to initialize ImageMetadataService', e, stack, 'ImageMetadataService');
      rethrow;
    }
  }

  Box<String> _getBox() {
    if (_persistentBox == null || !_persistentBox!.isOpen) {
      throw StateError('ImageMetadataService not initialized. Call initialize() first.');
    }
    return _persistentBox!;
  }

  // ============================================================
  // 对外 API
  // ============================================================

  /// 前台立即获取元数据（高优先级）
  ///
  /// **使用场景**：用户主动打开图像详情页
  /// **特点**：
  /// - 最高优先级，不受后台预加载队列影响
  /// - 立即开始解析，不加入队列等待
  /// - 如果同文件正在被后台处理，共享结果
  ///
  /// [path] 文件路径
  Future<NaiImageMetadata?> getMetadataImmediate(String path) async {
    // 1. 内存缓存检查
    final memoryCached = _memoryCache.get(path);
    if (memoryCached != null) {
      _cacheHits++;
      AppLogger.d('Memory cache hit (immediate): $path', 'ImageMetadataService');
      return memoryCached;
    }

    // 2. 持久缓存检查
    final persistentCached = _getFromPersistentCache(path);
    if (persistentCached != null) {
      _cacheHits++;
      _memoryCache.put(path, persistentCached);
      AppLogger.d('Persistent cache hit (immediate): $path', 'ImageMetadataService');
      return persistentCached;
    }

    _cacheMisses++;

    // 3. 检查是否正在解析中（后台或前台）
    if (_pendingFutures.containsKey(path)) {
      AppLogger.d('Already loading (sharing): $path', 'ImageMetadataService');
      return _pendingFutures[path]!;
    }

    // 4. 立即开始解析（高优先级）
    // 从后台队列中移除（如果存在）
    _removeFromPreloadQueue(path);

    // 使用高优先级信号量槽位
    await _highPrioritySemaphore.acquire();

    // 双重检查
    final doubleCheck = _memoryCache.get(path);
    if (doubleCheck != null) {
      _highPrioritySemaphore.release();
      return doubleCheck;
    }

    AppLogger.i('Immediate parse started: $path', 'ImageMetadataService');
    final future = _parseAndCache(path, forceFullParse: false);
    _pendingFutures[path] = future;

    try {
      final result = await future;
      AppLogger.i('Immediate parse completed: $path', 'ImageMetadataService');
      return result;
    } finally {
      _pendingFutures.remove(path);
      _highPrioritySemaphore.release();
    }
  }

  /// 从文件路径获取元数据（标准入口）
  ///
  /// **使用场景**：后台预加载、批量处理
  /// **特点**：
  /// - 标准优先级
  /// - 可能被前台请求打断或共享
  ///
  /// 自动处理以下逻辑：
  /// 1. 检查内存缓存（快速返回）
  /// 2. 检查持久缓存（加载到内存后返回）
  /// 3. 解析文件（并存入两级缓存）
  Future<NaiImageMetadata?> getMetadata(
    String path, {
    bool forceFullParse = false,
  }) async {
    // 1. 内存缓存检查
    final memoryCached = _memoryCache.get(path);
    if (memoryCached != null) {
      _cacheHits++;
      AppLogger.d('Memory cache hit: $path', 'ImageMetadataService');
      return memoryCached;
    }

    // 2. 持久缓存检查
    final persistentCached = _getFromPersistentCache(path);
    if (persistentCached != null) {
      _cacheHits++;
      // 回填内存缓存
      _memoryCache.put(path, persistentCached);
      AppLogger.d('Persistent cache hit: $path', 'ImageMetadataService');
      return persistentCached;
    }

    _cacheMisses++;

    // 3. 检查是否正在解析中
    if (_pendingFutures.containsKey(path)) {
      AppLogger.d('Already loading: $path', 'ImageMetadataService');
      return _pendingFutures[path]!;
    }

    // 4. 文件解析（标准优先级）
    await _fileSemaphore.acquire();

    // 双重检查（可能在等待信号量期间其他线程已完成）
    final doubleCheck = _memoryCache.get(path);
    if (doubleCheck != null) {
      _fileSemaphore.release();
      return doubleCheck;
    }

    final future = _parseAndCache(path, forceFullParse: forceFullParse);
    _pendingFutures[path] = future;

    try {
      return await future;
    } finally {
      _pendingFutures.remove(path);
      _fileSemaphore.release();
    }
  }

  /// 从字节数组获取元数据（用于拖拽、生成的图像等）
  ///
  /// [cacheKey] 可选的缓存键（如后续会保存的文件路径），用于持久化缓存
  Future<NaiImageMetadata?> getMetadataFromBytes(
    Uint8List bytes, {
    String? cacheKey,
  }) async {
    final key = cacheKey ?? _computeBytesHash(bytes);

    // 1. 内存缓存检查
    final memoryCached = _memoryCache.get(key);
    if (memoryCached != null) {
      _cacheHits++;
      return memoryCached;
    }

    // 2. 持久缓存检查（如果有 cacheKey）
    if (cacheKey != null) {
      final persistentCached = _getFromPersistentCache(cacheKey);
      if (persistentCached != null) {
        _cacheHits++;
        _memoryCache.put(key, persistentCached);
        return persistentCached;
      }
    }

    _cacheMisses++;

    // 3. 检查是否正在解析中
    if (_pendingFutures.containsKey(key)) {
      return _pendingFutures[key]!;
    }

    // 4. 字节解析
    final future = _parseBytesAndCache(bytes, cacheKey: cacheKey);
    _pendingFutures[key] = future;

    try {
      return await future;
    } finally {
      _pendingFutures.remove(key);
    }
  }

  /// 将图像加入预加载队列（后台解析）
  ///
  /// 用于生成完成后批量预解析，不阻塞主流程
  void enqueuePreload({
    required String taskId,
    String? filePath,
    Uint8List? bytes,
  }) {
    // 检查是否已缓存
    if (filePath != null && (_memoryCache.get(filePath) != null || _isInPersistentCache(filePath))) {
      return;
    }

    // 检查是否已在队列中
    if (_preloadQueue.any((t) => t.taskId == taskId) || _processingTaskIds.contains(taskId)) {
      return;
    }

    // 队列满了则移除最旧的任务
    if (_preloadQueue.length >= _maxQueueSize) {
      _preloadQueue.removeAt(0);
      AppLogger.w('Preload queue full, dropped oldest task', 'ImageMetadataService');
    }

    _preloadQueue.add(
      _PreloadTask(
        taskId: taskId,
        filePath: filePath,
        bytes: bytes,
      ),
    );

    _processPreloadQueue();
  }

  /// 批量预加载
  void enqueuePreloadBatch(List<GeneratedImageInfo> images) {
    for (final image in images) {
      enqueuePreload(
        taskId: image.id,
        filePath: image.filePath,
        bytes: image.bytes,
      );
    }
  }

  /// 手动缓存元数据（用于外部已解析的元数据）
  void cacheMetadata(String path, NaiImageMetadata metadata) {
    if (!metadata.hasData) return;
    _memoryCache.put(path, metadata);
    _saveToPersistentCache(path, metadata);
  }

  /// 获取缓存统计
  Map<String, dynamic> getStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'persistentCacheSize': _persistentBox?.length ?? 0,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': _cacheHits + _cacheMisses > 0
          ? '${(_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1)}%'
          : 'N/A',
      'fastParseCount': _fastParseCount,
      'fallbackParseCount': _fallbackParseCount,
      'parseErrors': _parseErrors,
      'preloadQueue': {
        'queueLength': _preloadQueue.length,
        'processingCount': _processingTaskIds.length,
        'successCount': _preloadSuccessCount,
        'errorCount': _preloadErrorCount,
      },
    };
  }

  /// 获取缓存中的元数据（同步，可能为 null）
  ///
  /// 注意：此方法只检查内存缓存，不查询持久缓存（异步）
  NaiImageMetadata? getCached(String path) {
    return _memoryCache.get(path);
  }

  /// 预加载指定路径的元数据（后台）
  void preload(String path) {
    enqueuePreload(taskId: path, filePath: path);
  }

  /// 批量预加载（兼容旧 API）
  void preloadBatch(List<GeneratedImageInfo> images) {
    enqueuePreloadBatch(images);
  }

  /// 获取预加载队列状态
  Map<String, dynamic> getPreloadQueueStatus() {
    return {
      'queueLength': _preloadQueue.length,
      'processingCount': _processingTaskIds.length,
      'isProcessing': _isProcessingQueue,
      'successCount': _preloadSuccessCount,
      'errorCount': _preloadErrorCount,
    };
  }

  /// 从后台预加载队列中移除指定任务
  ///
  /// 当用户主动打开图像时调用，避免重复处理
  void _removeFromPreloadQueue(String taskId) {
    final initialLength = _preloadQueue.length;
    _preloadQueue.removeWhere((task) => task.taskId == taskId);
    if (_preloadQueue.length < initialLength) {
      AppLogger.d('Removed from preload queue: $taskId', 'ImageMetadataService');
    }
  }

  /// 清空所有缓存
  Future<void> clearCache() async {
    _memoryCache.clear();
    await _persistentBox?.clear();
    AppLogger.i('All caches cleared', 'ImageMetadataService');
  }

  // ============================================================
  // 内部实现
  // ============================================================

  /// 解析文件并缓存
  Future<NaiImageMetadata?> _parseAndCache(
    String path, {
    required bool forceFullParse,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      if (!path.toLowerCase().endsWith('.png')) return null;

      NaiImageMetadata? metadata;

      // 尝试快速解析
      if (!forceFullParse) {
        metadata = await _extractMetadataFast(file);
        if (metadata != null) {
          _fastParseCount++;
        }
      }

      // Fallback 到完整解析
      if (metadata == null) {
        metadata = await NaiMetadataParser.extractFromFile(file);
        if (metadata != null) {
          _fallbackParseCount++;
        }
      }

      // 存入两级缓存
      if (metadata != null && metadata.hasData) {
        _memoryCache.put(path, metadata);
        await _saveToPersistentCache(path, metadata);
      }

      return metadata;
    } catch (e, stack) {
      _parseErrors++;
      AppLogger.e('Parse failed: $path', e, stack, 'ImageMetadataService');
      return null;
    }
  }

  /// 解析字节并缓存
  Future<NaiImageMetadata?> _parseBytesAndCache(
    Uint8List bytes, {
    String? cacheKey,
  }) async {
    try {
      if (bytes.length < 8) return null;

      NaiImageMetadata? metadata;

      // 尝试快速解析
      if (bytes.length <= _streamBufferSize) {
        metadata = _extractFromChunks(bytes);
      } else {
        metadata = _extractFromChunks(bytes.sublist(0, _streamBufferSize));
      }

      // Fallback
      metadata ??= await NaiMetadataParser.extractFromBytes(bytes);

      // 存入缓存
      if (metadata != null && metadata.hasData) {
        final key = cacheKey ?? _computeBytesHash(bytes);
        _memoryCache.put(key, metadata);
        if (cacheKey != null) {
          await _saveToPersistentCache(cacheKey, metadata);
        }
      }

      return metadata;
    } catch (e, stack) {
      _parseErrors++;
      AppLogger.e('Parse bytes failed', e, stack, 'ImageMetadataService');
      return null;
    }
  }

  /// 快速流式解析（只读前50KB）
  Future<NaiImageMetadata?> _extractMetadataFast(File file) async {
    final raf = await file.open();
    try {
      final buffer = await raf.read(_streamBufferSize);
      if (buffer.length < 8) return null;

      const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      for (var i = 0; i < 8; i++) {
        if (buffer[i] != pngSignature[i]) return null;
      }

      return _extractFromChunks(buffer);
    } finally {
      await raf.close();
    }
  }

  /// 从 chunks 提取元数据
  NaiImageMetadata? _extractFromChunks(Uint8List bytes) {
    final chunks = _extractChunks(bytes);
    for (final chunk in chunks) {
      if (chunk.name == 'tEXt' || chunk.name == 'zTXt' || chunk.name == 'iTXt') {
        final text = _parseTextChunk(chunk.data, chunk.name);
        if (text != null) {
          final json = _tryParseNaiJson(text);
          if (json != null) {
            return NaiImageMetadata.fromNaiComment(json, rawJson: text);
          }
        }
      }
    }
    return null;
  }

  /// 提取 PNG chunks
  List<_PngChunk> _extractChunks(Uint8List bytes) {
    final chunks = <_PngChunk>[];
    var offset = 8;

    while (offset + 12 <= bytes.length) {
      final length = _readUint32(bytes, offset);
      offset += 4;
      if (offset + 4 > bytes.length) break;
      final name = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      offset += 4;
      if (offset + length > bytes.length) break;
      final data = bytes.sublist(offset, offset + length);
      offset += length + 4; // skip CRC
      chunks.add(_PngChunk(name: name, data: data));
      if (name == 'IDAT') break;
    }

    return chunks;
  }

  /// 解析 text chunk
  String? _parseTextChunk(Uint8List data, String chunkType) {
    try {
      return switch (chunkType) {
        'tEXt' => _parseTEXt(data),
        'zTXt' => _parseZTXt(data),
        'iTXt' => _parseITXt(data),
        _ => null,
      };
    } catch (e) {
      return null;
    }
  }

  String? _parseTEXt(Uint8List data) {
    final nullIndex = data.indexOf(0);
    if (nullIndex < 0) return null;
    return latin1.decode(data.sublist(nullIndex + 1));
  }

  String? _parseZTXt(Uint8List data) {
    final firstNull = data.indexOf(0);
    if (firstNull < 0 || firstNull + 1 >= data.length) return null;
    if (data[firstNull + 1] != 0) return null;
    return _inflateZlib(data.sublist(firstNull + 2));
  }

  String? _parseITXt(Uint8List data) {
    var offset = 0;
    final keywordEnd = data.indexOf(0, offset);
    if (keywordEnd < 0) return null;
    offset = keywordEnd + 1;
    if (offset + 1 >= data.length) return null;
    final compressed = data[offset++];
    final method = data[offset++];
    final langEnd = data.indexOf(0, offset);
    if (langEnd < 0) return null;
    offset = langEnd + 1;
    final transEnd = data.indexOf(0, offset);
    if (transEnd < 0) return null;
    offset = transEnd + 1;
    if (offset >= data.length) return null;
    final textData = data.sublist(offset);
    if (compressed == 1) {
      if (method != 0) return null;
      return _inflateZlib(textData);
    }
    return utf8.decode(textData);
  }

  String? _inflateZlib(Uint8List data) {
    try {
      final inflated = ZLibCodec().decode(data);
      return utf8.decode(inflated);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _tryParseNaiJson(String text) {
    try {
      final lowerText = text.toLowerCase();
      if (!lowerText.contains('prompt') &&
          !lowerText.contains('sampler') &&
          !lowerText.contains('steps')) {
        return null;
      }
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json.containsKey('prompt') || json.containsKey('comment')) {
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  String _computeBytesHash(Uint8List bytes) {
    final sampleSize = bytes.length < 1024 ? bytes.length : 1024;
    var hash = 0;
    for (var i = 0; i < sampleSize; i++) {
      hash = ((hash << 5) - hash) + bytes[i];
      hash = hash & 0xFFFFFFFF;
    }
    return '${hash}_${bytes.length}';
  }

  // ============================================================
  // 持久缓存操作
  // ============================================================

  NaiImageMetadata? _getFromPersistentCache(String key) {
    try {
      final box = _getBox();
      final jsonString = box.get(key);
      if (jsonString == null) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NaiImageMetadata.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToPersistentCache(String key, NaiImageMetadata metadata) async {
    try {
      final box = _getBox();
      // 清理旧数据（如果超过1000条）
      if (box.length >= 1000) {
        final keysToDelete = box.keys.take(100).toList();
        for (final k in keysToDelete) {
          await box.delete(k);
        }
      }
      final jsonString = jsonEncode(metadata.toJson());
      await box.put(key, jsonString);
    } catch (e) {
      AppLogger.w('Failed to save to persistent cache: $key', 'ImageMetadataService');
    }
  }

  bool _isInPersistentCache(String key) {
    try {
      return _getBox().containsKey(key);
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 预加载队列
  // ============================================================

  Future<void> _processPreloadQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_preloadQueue.isNotEmpty) {
      final batchSize = _preloadQueue.length < _preloadConcurrency
          ? _preloadQueue.length
          : _preloadConcurrency;
      final batch = _preloadQueue.sublist(0, batchSize);
      _preloadQueue.removeRange(0, batchSize);

      for (final task in batch) {
        _processingTaskIds.add(task.taskId);
      }

      await Future.wait(batch.map((task) => _processPreloadTask(task)));

      for (final task in batch) {
        _processingTaskIds.remove(task.taskId);
      }
    }

    _isProcessingQueue = false;
  }

  Future<void> _processPreloadTask(_PreloadTask task) async {
    try {
      // 检查是否已被前台请求处理中或已完成
      if (_pendingFutures.containsKey(task.taskId)) {
        AppLogger.d('Skipping preload, already being processed: ${task.taskId}', 'ImageMetadataService');
        // 等待前台处理完成，共享结果
        await _pendingFutures[task.taskId]!;
        return;
      }

      // 检查是否已缓存
      if (_memoryCache.get(task.taskId) != null) {
        return;
      }

      NaiImageMetadata? metadata;
      if (task.filePath != null) {
        metadata = await getMetadata(task.filePath!);
      } else if (task.bytes != null) {
        metadata = await getMetadataFromBytes(task.bytes!, cacheKey: task.taskId);
      }
      if (metadata != null && metadata.hasData) {
        _preloadSuccessCount++;
      } else {
        _preloadErrorCount++;
      }
    } catch (e) {
      _preloadErrorCount++;
    }
  }
}

// ============================================================
// 辅助类
// ============================================================

class _PngChunk {
  final String name;
  final Uint8List data;

  _PngChunk({required this.name, required this.data});
}

class GeneratedImageInfo {
  final String id;
  final String? filePath;
  final Uint8List? bytes;

  GeneratedImageInfo({required this.id, this.filePath, this.bytes});
}

class _PreloadTask {
  final String taskId;
  final String? filePath;
  final Uint8List? bytes;

  _PreloadTask({required this.taskId, this.filePath, this.bytes});
}

class _LRUCache<K, V> {
  final int capacity;
  final _map = <K, V>{};

  _LRUCache({required this.capacity});

  int get length => _map.length;

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    while (_map.length >= capacity) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);

  void clear() => _map.clear();
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
    } else {
      _currentCount--;
    }
  }
}
