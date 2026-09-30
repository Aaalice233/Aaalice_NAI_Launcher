import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 文件哈希计算器
///
/// 提供文件 SHA256 哈希计算，支持：
/// - 异步文件读取
/// - 并发控制
/// - 去重（相同路径同时只有一个计算任务）
/// - 路径到哈希的映射缓存（按文件身份校验，文件被改写后自动失效）
class FileHashCalculator {
  static final FileHashCalculator _instance = FileHashCalculator._internal();
  factory FileHashCalculator() => _instance;
  FileHashCalculator._internal();

  final _pathEntries = <String, _PathHashEntry>{};
  final _pendingHashFutures = <String, Future<String>>{};
  final _semaphore = _Semaphore(3);

  int _hashComputeCount = 0;
  int _hashCacheHitCount = 0;

  /// 计算文件哈希（带缓存和并发控制）
  Future<String> calculate(String filePath) async {
    final cached = _pathEntries[filePath];
    if (cached != null) {
      if (cached.identity == await _FileIdentity.stat(filePath)) {
        _hashCacheHitCount++;
        return cached.hash;
      }
      _forget(filePath, cached);
    }

    // 检查是否有正在进行的计算
    final pendingFuture = _pendingHashFutures[filePath];
    if (pendingFuture != null) {
      return pendingFuture;
    }

    // 创建新的计算任务
    final future = _calculateWithSemaphore(filePath);
    _pendingHashFutures[filePath] = future;

    try {
      final hash = await future;
      return hash;
    } finally {
      _pendingHashFutures.remove(filePath);
    }
  }

  /// 从字节数据计算哈希（同步）
  String calculateFromBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// 登记刚写入文件的哈希，文件已不存在时不登记
  Future<void> registerPathHash(String filePath, String hash) async {
    final identity = await _FileIdentity.stat(filePath);
    if (identity == null) return;
    _pathEntries[filePath] = _PathHashEntry(hash, identity);
  }

  /// 同步返回与当前文件身份一致的已知哈希，文件变化或不存在时丢弃映射
  String? verifiedHashForPathSync(String filePath) {
    final cached = _pathEntries[filePath];
    if (cached == null) return null;
    if (cached.identity == _FileIdentity.statSync(filePath)) {
      return cached.hash;
    }
    _forget(filePath, cached);
    return null;
  }

  /// 不校验文件身份，只用于按路径定位已发起的解析任务
  String? getHashForPath(String path) => _pathEntries[path]?.hash;

  /// 清除所有缓存
  void clearCache() {
    _pathEntries.clear();
    _pendingHashFutures.clear();
  }

  // ==================== 统计信息 ====================

  int get hashComputeCount => _hashComputeCount;
  int get hashCacheHitCount => _hashCacheHitCount;

  Map<String, dynamic> getStatistics() => {
    'hashComputeCount': _hashComputeCount,
    'hashCacheHitCount': _hashCacheHitCount,
    'pendingCalculations': _pendingHashFutures.length,
    'pathMappings': _pathEntries.length,
  };

  void resetStatistics() {
    _hashComputeCount = 0;
    _hashCacheHitCount = 0;
  }

  // ==================== 私有方法 ====================

  Future<String> _calculateWithSemaphore(String filePath) async {
    await _semaphore.acquire();
    try {
      final before = await _FileIdentity.stat(filePath);
      final bytes = await File(filePath).readAsBytes();
      final hash = sha256.convert(bytes).toString();

      // 读取期间文件被改写时不登记映射，下次重新计算
      if (before != null && before == await _FileIdentity.stat(filePath)) {
        _pathEntries[filePath] = _PathHashEntry(hash, before);
      }

      _hashComputeCount++;
      return hash;
    } finally {
      _semaphore.release();
    }
  }

  void _forget(String filePath, _PathHashEntry stale) {
    if (identical(_pathEntries[filePath], stale)) {
      _pathEntries.remove(filePath);
    }
  }
}

final class _PathHashEntry {
  const _PathHashEntry(this.hash, this.identity);

  final String hash;
  final _FileIdentity identity;
}

/// 同一路径上的文件是否仍是计算哈希时那一份
final class _FileIdentity {
  const _FileIdentity({
    required this.size,
    required this.modifiedMicros,
    required this.changedMicros,
  });

  static Future<_FileIdentity?> stat(String path) async =>
      _fromStat(await FileStat.stat(path));

  static _FileIdentity? statSync(String path) =>
      _fromStat(FileStat.statSync(path));

  static _FileIdentity? _fromStat(FileStat stat) {
    if (stat.type != FileSystemEntityType.file) return null;
    return _FileIdentity(
      size: stat.size,
      modifiedMicros: stat.modified.microsecondsSinceEpoch,
      changedMicros: stat.changed.microsecondsSinceEpoch,
    );
  }

  final int size;
  final int modifiedMicros;
  // Windows 上是创建时间，POSIX 上是 inode 变更时间，能识别保留 mtime 的替换
  final int changedMicros;

  @override
  bool operator ==(Object other) =>
      other is _FileIdentity &&
      other.size == size &&
      other.modifiedMicros == modifiedMicros &&
      other.changedMicros == changedMicros;

  @override
  int get hashCode => Object.hash(size, modifiedMicros, changedMicros);
}

/// 信号量（并发控制）
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
