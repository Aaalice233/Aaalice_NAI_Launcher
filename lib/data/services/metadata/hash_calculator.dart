import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/utils/isolate_pool.dart';
import '../../../core/utils/local_file_identity.dart';

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

  // 低于此体积时同步计算比 isolate 往返更快
  static const int backgroundHashMinBytes = 64 * 1024;

  final _pathEntries = <String, _PathHashEntry>{};
  final _pendingSnapshots = <String, Future<FileHashSnapshot>>{};
  final _semaphore = _Semaphore(3);

  int _hashComputeCount = 0;
  int _hashCacheHitCount = 0;

  /// 计算文件哈希（带缓存和并发控制），并记下当时的文件身份供另行读取内容后核对
  Future<FileHashSnapshot> snapshot(String filePath) async {
    final cached = _pathEntries[filePath];
    if (cached != null) {
      if (cached.identity == await LocalFileIdentity.stat(filePath)) {
        _hashCacheHitCount++;
        return FileHashSnapshot._(filePath, cached.hash, cached.identity);
      }
      _forget(filePath, cached);
    }

    // 检查是否有正在进行的计算
    final pending = _pendingSnapshots[filePath];
    if (pending != null) {
      return pending;
    }

    // 创建新的计算任务
    final future = _calculateWithSemaphore(filePath);
    _pendingSnapshots[filePath] = future;

    try {
      return await future;
    } finally {
      _pendingSnapshots.remove(filePath);
    }
  }

  /// 从字节数据计算哈希（同步）
  String calculateFromBytes(Uint8List bytes) => _sha256OfBytes(bytes);

  /// 与 [calculateFromBytes] 结果一致；较大的数据经 [ComputeGate] 在后台 isolate 计算
  Future<String> calculateFromBytesInBackground(Uint8List bytes) async {
    if (bytes.length < backgroundHashMinBytes) {
      return _sha256OfBytes(bytes);
    }
    return ComputeGate().runCompute(_sha256OfBytes, bytes);
  }

  /// 登记刚写入 [filePath] 的 [bytes] 并返回其哈希；文件已不存在或已被替换时不登记
  Future<String> registerWrittenBytes(String filePath, Uint8List bytes) async {
    // 先取身份再算哈希：后台哈希可能排队，期间被替换的内容不能顶着这份哈希登记
    final identity = await LocalFileIdentity.stat(filePath);
    final hash = await calculateFromBytesInBackground(bytes);
    if (identity != null && identity.size == bytes.length) {
      _pathEntries[filePath] = _PathHashEntry(hash, identity);
    }
    return hash;
  }

  /// 返回与当前文件身份一致的已知哈希，文件变化或不存在时丢弃映射
  Future<String?> verifiedHashForPath(String filePath) async {
    final cached = _pathEntries[filePath];
    if (cached == null) return null;
    return _verified(filePath, cached, await LocalFileIdentity.stat(filePath));
  }

  /// 同 [verifiedHashForPath]，只给首帧就要出结果的同步读取用
  String? verifiedHashForPathSync(String filePath) {
    final cached = _pathEntries[filePath];
    if (cached == null) return null;
    return _verified(filePath, cached, LocalFileIdentity.statSync(filePath));
  }

  /// 不校验文件身份，只用于按路径定位已发起的解析任务
  String? getHashForPath(String path) => _pathEntries[path]?.hash;

  /// 清除所有缓存
  void clearCache() {
    _pathEntries.clear();
    _pendingSnapshots.clear();
  }

  // ==================== 统计信息 ====================

  int get hashComputeCount => _hashComputeCount;
  int get hashCacheHitCount => _hashCacheHitCount;

  Map<String, dynamic> getStatistics() => {
    'hashComputeCount': _hashComputeCount,
    'hashCacheHitCount': _hashCacheHitCount,
    'pendingCalculations': _pendingSnapshots.length,
    'pathMappings': _pathEntries.length,
  };

  void resetStatistics() {
    _hashComputeCount = 0;
    _hashCacheHitCount = 0;
  }

  // ==================== 私有方法 ====================

  Future<FileHashSnapshot> _calculateWithSemaphore(String filePath) async {
    await _semaphore.acquire();
    try {
      final before = await LocalFileIdentity.stat(filePath);
      final hash = before != null && before.size >= backgroundHashMinBytes
          ? await ComputeGate().runCompute(_sha256OfFile, filePath)
          : _sha256OfBytes(await File(filePath).readAsBytes());

      // 读取期间文件被改写时不登记映射，下次重新计算
      final stable =
          before != null && before == await LocalFileIdentity.stat(filePath);
      if (stable) {
        _pathEntries[filePath] = _PathHashEntry(hash, before);
      }

      _hashComputeCount++;
      return FileHashSnapshot._(filePath, hash, stable ? before : null);
    } finally {
      _semaphore.release();
    }
  }

  String? _verified(
    String filePath,
    _PathHashEntry cached,
    LocalFileIdentity? identity,
  ) {
    if (cached.identity == identity) return cached.hash;
    _forget(filePath, cached);
    return null;
  }

  void _forget(String filePath, _PathHashEntry stale) {
    if (identical(_pathEntries[filePath], stale)) {
      _pathEntries.remove(filePath);
    }
  }

  static String _sha256OfBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  static Future<String> _sha256OfFile(String filePath) async {
    return (await sha256.bind(File(filePath).openRead()).first).toString();
  }
}

/// 某路径在算出 [hash] 那一刻的文件身份
final class FileHashSnapshot {
  const FileHashSnapshot._(this.filePath, this.hash, this._identity);

  final String filePath;
  final String hash;

  // 哈希读取期间文件就被改写时为 null，此后读到的任何内容都不能记在 [hash] 下
  final LocalFileIdentity? _identity;

  /// 文件是否仍是算哈希时那一份；另行读取内容后据此决定结果能否记在 [hash] 下
  Future<bool> isUnchanged() async =>
      _identity != null && _identity == await LocalFileIdentity.stat(filePath);
}

final class _PathHashEntry {
  const _PathHashEntry(this.hash, this.identity);

  final String hash;
  final LocalFileIdentity identity;
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
