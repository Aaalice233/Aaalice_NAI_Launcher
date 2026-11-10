import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'
    show MissingPlatformDirectoryException;

import '../utils/app_logger.dart';
import '../utils/isolate_pool.dart';
import 'storage_file_system.dart';

typedef QueueBlobWorker =
    Future<T> Function<T>(FutureOr<T> Function() task, {String? debugName});

/// 队列快照中一个二进制槽位引用的图片文件。
class QueueBlobRef {
  const QueueBlobRef(this.sha256, this.length);

  final String sha256;
  final int length;

  static final RegExp _digest = RegExp(r'^[0-9a-f]{64}$');

  static bool isDigest(String value) => _digest.hasMatch(value);

  static QueueBlobRef parse(Object? json) =>
      tryParse(json) ??
      (throw const FormatException('Invalid queued image reference'));

  /// 恰好由合法的 `sha256` 与 `length` 两个字段组成时返回引用，否则返回 null。
  static QueueBlobRef? tryParse(Object? json) {
    if (json is! Map || json.length != 2) return null;
    final digest = json['sha256'];
    final length = json['length'];
    if (digest is! String ||
        !isDigest(digest) ||
        length is! int ||
        length < 0) {
      return null;
    }
    return QueueBlobRef(digest, length);
  }

  Map<String, dynamic> toJson() => {'sha256': sha256, 'length': length};

  String get shortId => sha256.substring(0, 12);

  @override
  bool operator ==(Object other) =>
      other is QueueBlobRef && other.sha256 == sha256 && other.length == length;

  @override
  int get hashCode => Object.hash(sha256, length);
}

/// 引用的图片文件不存在或无法读取。
class QueueBlobMissingException extends FormatException {
  QueueBlobMissingException(String shortId)
    : super('Queued image data is missing or unreadable ($shortId)');

  @override
  String toString() => message;
}

/// 引用的图片文件长度或摘要与引用不符。
class QueueBlobCorruptException extends FormatException {
  QueueBlobCorruptException(this.digest)
    : super('Queued image data is corrupt (${digest.substring(0, 12)})');

  final String digest;

  @override
  String toString() => message;
}

/// 读取过程本身出错（文件被占用、后台 isolate 失败等），稍后可以重试；
/// 不属于快照无效，与图片缺失或损坏区分开。
class QueueBlobReadFailedException implements Exception {
  QueueBlobReadFailedException(Object cause)
    : message =
          'Queued image data could not be loaded '
          '(${cause.runtimeType}${_osErrorSuffix(cause)})';

  /// 记在任务上的失败原因，界面按它给出本地化说明；不含路径与系统错误文本。
  static const String errorCode = 'QUEUE_IMAGES_UNAVAILABLE';

  final String message;

  static String _osErrorSuffix(Object cause) {
    final code = cause is FileSystemException ? cause.osError?.errorCode : null;
    return code == null ? '' : ', os error $code';
  }

  @override
  String toString() => message;
}

class QueueBlobWriteException implements Exception {
  const QueueBlobWriteException(this.message);

  final String message;

  @override
  String toString() => 'QueueBlobWriteException: $message';
}

/// 读取时的校验强度：执行前必须完整校验，估价只需确认文件在且长度对。
enum QueueBlobVerification { lengthOnly, full }

/// 落盘后到索引引用它们之前，持有期间的摘要不会被清扫。
class QueueBlobLease {
  QueueBlobLease._(this.refs, this._onRelease);

  final List<QueueBlobRef> refs;
  final void Function() _onRelease;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

/// 队列快照图片的内容寻址文件存储：文件名即 SHA-256，写入与清扫共用一个串行执行器。
class ReplicationQueueBlobStore {
  ReplicationQueueBlobStore({
    required Future<String> Function() resolveDirectory,
    StorageFileSystem fileSystem = const StorageFileSystem(),
    QueueBlobWorker? worker,
  }) : _resolveDirectory = resolveDirectory,
       _fileSystem = fileSystem,
       _worker = worker ?? ComputeGate().runIsolate;

  static const String directoryName = 'replication_queue_blobs';
  static const String _temporarySuffix = '.tmp';
  static const String _tag = 'QueueBlobStore';

  final Future<String> Function() _resolveDirectory;
  final StorageFileSystem _fileSystem;
  final QueueBlobWorker _worker;
  final Map<String, int> _pins = {};
  Future<void> _tail = Future.value();
  Future<String>? _directory;

  /// 串行执行器当前排队的写入与清扫全部结束。
  Future<void> get idle => _tail;

  Future<String> directory() => _directory ??= _resolveDirectory().catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _directory = null;
    Error.throwWithStackTrace(error, stackTrace);
  });

  // 后台 isolate 异常终止时图片未能落盘，按写入失败处理
  Future<QueueBlobLease> put(List<Uint8List> blobs) => _serial(() async {
    if (blobs.isEmpty) return QueueBlobLease._(const [], () {});
    final List<String> digests;
    try {
      digests = await _offload(
        _worker,
        'QueueBlobStore.put',
        _fileSystem,
        await directory(),
        blobs,
        _hashAndStore,
      );
    } on QueueBlobWriteException {
      rethrow;
    } on RemoteError catch (error) {
      throw QueueBlobWriteException(
        'Failed to store queued images (${error.runtimeType})',
      );
    } on Exception catch (error) {
      if (error
          case FileSystemException() ||
              PlatformException() ||
              MissingPluginException() ||
              MissingPlatformDirectoryException()) {
        throw QueueBlobWriteException(
          'Failed to store queued images (${error.runtimeType})',
        );
      }
      rethrow;
    }
    final refs = [
      for (var index = 0; index < blobs.length; index++)
        QueueBlobRef(digests[index], blobs[index].length),
    ];
    for (final ref in refs) {
      _pins.update(ref.sha256, (count) => count + 1, ifAbsent: () => 1);
    }
    return QueueBlobLease._(refs, () {
      for (final ref in refs) {
        final count = _pins[ref.sha256]! - 1;
        if (count == 0) {
          _pins.remove(ref.sha256);
        } else {
          _pins[ref.sha256] = count;
        }
      }
    });
  });

  /// 按引用在后台读取并按 [verify] 校验，结果与 [refs] 一一对应。
  ///
  /// 缺失与损坏以 [FormatException] 子类报出，调用方按无效快照结算；读取过程出错以
  /// [QueueBlobReadFailedException] 报出，可以重试。校验出损坏的文件经复查后删除，
  /// 下一次相同内容入队时会重写。
  Future<List<Uint8List>> read(
    List<QueueBlobRef> refs, {
    QueueBlobVerification verify = QueueBlobVerification.full,
  }) async {
    if (refs.isEmpty) return const [];
    try {
      return await _offload(
        _worker,
        'QueueBlobStore.read',
        _fileSystem,
        await directory(),
        (refs: refs, verify: verify),
        _readVerified,
      );
    } on QueueBlobCorruptException catch (error) {
      unawaited(_discardCorrupt(error.digest));
      rethrow;
    } on QueueBlobMissingException {
      rethrow;
    } on QueueBlobReadFailedException {
      rethrow;
    } catch (error) {
      throw QueueBlobReadFailedException(error);
    }
  }

  // 读取不经串行执行器，排到这里时同一摘要可能已被入队重写，删除前要复查
  Future<void> _discardCorrupt(String digest) => _serial(() async {
    if (_pins.containsKey(digest)) return;
    try {
      final directory = await this.directory();
      final corrupt = await _offload(
        _worker,
        'QueueBlobStore.recheck',
        _fileSystem,
        directory,
        digest,
        _isStillCorrupt,
      );
      if (corrupt) await _fileSystem.delete(p.join(directory, digest));
    } catch (error) {
      AppLogger.w(
        'Corrupt queue image was not removed (${error.runtimeType})',
        _tag,
      );
    }
  });

  /// 删除不在 [liveDigests] 中且未被租约持有的图片及残留临时文件。
  ///
  /// [liveDigests] 在列出目录之后才求值；返回 null 表示根集合无法确定，本次放弃清扫。
  Future<int> collect(Set<String>? Function() liveDigests) => _serial(() async {
    final directory = await this.directory();
    final names = <String>[];
    try {
      await for (final entity in _fileSystem.list(directory)) {
        if (entity is File) names.add(p.basename(entity.path));
      }
    } on PathNotFoundException {
      return 0;
    }
    // 让出一轮事件循环：put 之后只由微任务组成的入队链先把任务写进状态，根集合直接包含它们
    await Future<void>(() {});
    final live = liveDigests();
    if (live == null) return 0;
    // 与根集合同一时刻取快照：之后才释放的租约，其任务不一定在这份根集合里
    final leased = Set<String>.of(_pins.keys);
    var removed = 0;
    var retained = 0;
    for (final name in names) {
      final removable = name.endsWith(_temporarySuffix)
          ? true
          : QueueBlobRef.isDigest(name) &&
                !live.contains(name) &&
                !leased.contains(name);
      if (!removable) continue;
      try {
        await _fileSystem.delete(p.join(directory, name));
        removed++;
      } on FileSystemException {
        // Windows 上文件可能被杀毒或读取占用，留给下一次清扫
        retained++;
      }
    }
    if (retained > 0) {
      AppLogger.w('Queue image sweep deferred $retained file(s)', _tag);
    }
    return removed;
  });

  /// 在本存储的后台 worker 上对图片目录执行 [task]；[task] 须为顶层或静态函数，
  /// [argument] 与返回值须可跨 isolate 传递。
  Future<R> runOnWorker<A, R>(
    String debugName,
    A argument,
    Future<R> Function(StorageFileSystem, String, A) task,
  ) async => _offload(
    _worker,
    debugName,
    _fileSystem,
    await directory(),
    argument,
    task,
  );

  /// 在调用方所在 isolate 内写入一个以 [digest] 命名的文件；目标已存在且长度一致时跳过。
  static Future<void> storeBlob(
    StorageFileSystem fileSystem,
    String directory,
    String digest,
    Uint8List bytes,
  ) async {
    final target = p.join(directory, digest);
    if (await fileSystem.exists(target) &&
        await fileSystem.length(target) == bytes.length) {
      return;
    }
    final temporary = p.join(
      directory,
      '$digest.${_uniqueSuffix()}$_temporarySuffix',
    );
    try {
      await fileSystem.writeBytes(temporary, bytes);
      await fileSystem.rename(temporary, target);
    } on FileSystemException catch (error) {
      try {
        if (await fileSystem.exists(temporary)) {
          await fileSystem.delete(temporary);
        }
      } on FileSystemException {
        // 残留的临时文件由下一次清扫删除
      }
      throw QueueBlobWriteException(
        'Failed to store queued image ${digest.substring(0, 12)} '
        '(os error ${error.osError?.errorCode})',
      );
    }
  }

  // 静态函数里创建闭包，只捕获可跨 isolate 发送的参数而不会带上 this
  static Future<R> _offload<A, R>(
    QueueBlobWorker worker,
    String debugName,
    StorageFileSystem fileSystem,
    String directory,
    A argument,
    Future<R> Function(StorageFileSystem, String, A) task,
  ) =>
      worker(() => task(fileSystem, directory, argument), debugName: debugName);

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Future<List<String>> _hashAndStore(
    StorageFileSystem fileSystem,
    String directory,
    List<Uint8List> blobs,
  ) async {
    try {
      await fileSystem.createDirectory(directory);
    } on FileSystemException catch (error) {
      throw QueueBlobWriteException(
        'Failed to create the queued image directory '
        '(os error ${error.osError?.errorCode})',
      );
    }
    final digests = <String>[];
    final stored = <String>{};
    for (final bytes in blobs) {
      final digest = sha256.convert(bytes).toString();
      digests.add(digest);
      if (stored.add(digest)) {
        await storeBlob(fileSystem, directory, digest, bytes);
      }
    }
    return digests;
  }

  static Future<List<Uint8List>> _readVerified(
    StorageFileSystem fileSystem,
    String directory,
    ({List<QueueBlobRef> refs, QueueBlobVerification verify}) request,
  ) async {
    final refs = request.refs;
    final hash = request.verify == QueueBlobVerification.full;
    final loaded = <QueueBlobRef, Uint8List>{};
    for (final ref in refs) {
      if (loaded.containsKey(ref)) continue;
      final Uint8List bytes;
      try {
        bytes = await fileSystem.readBytes(p.join(directory, ref.sha256));
      } on PathNotFoundException {
        throw QueueBlobMissingException(ref.shortId);
      } on FileSystemException catch (error) {
        throw QueueBlobReadFailedException(error);
      }
      if (bytes.length != ref.length ||
          hash && sha256.convert(bytes).toString() != ref.sha256) {
        throw QueueBlobCorruptException(ref.sha256);
      }
      loaded[ref] = bytes;
    }
    return [for (final ref in refs) loaded[ref]!];
  }

  /// 文件内容的摘要与文件名不符；文件已不存在时无需处理。
  static Future<bool> _isStillCorrupt(
    StorageFileSystem fileSystem,
    String directory,
    String digest,
  ) async {
    final Uint8List bytes;
    try {
      bytes = await fileSystem.readBytes(p.join(directory, digest));
    } on PathNotFoundException {
      return false;
    }
    return sha256.convert(bytes).toString() != digest;
  }

  static String _uniqueSuffix() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}'
        '-${random.nextInt(1 << 32).toRadixString(16)}';
  }
}
