import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/app_logger.dart';
import '../secure_storage_unavailable_exception.dart';
import 'dpapi_cipher.dart';

/// 文件被其他进程短暂占用时的重试节奏；[budget] 是一次读改写的总期限
class SecureFileRetryPolicy {
  const SecureFileRetryPolicy({
    this.initialDelay = const Duration(milliseconds: 10),
    this.maxDelay = const Duration(milliseconds: 50),
    this.jitter = 0.5,
    this.budget = const Duration(seconds: 5),
  });

  // 扫描器常见节奏是"占用数百毫秒、释放约 100 毫秒"：间隔须短于空档，抖动避免与其周期同相
  final Duration initialDelay;
  final Duration maxDelay;
  final double jitter;
  final Duration budget;
}

/// 整文件读写 DPAPI 加密的 JSON：占用时有限重试，写入经临时文件替换，损坏文件改名留档
class DpapiJsonFileStore {
  DpapiJsonFileStore({
    required Future<String> Function() directoryResolver,
    SecureBlobCipher cipher = const DpapiCipher(),
    SecureFileRetryPolicy retryPolicy = const SecureFileRetryPolicy(),
    DateTime Function() clock = DateTime.now,
  }) : _directoryResolver = directoryResolver,
       _cipher = cipher,
       _retryPolicy = retryPolicy,
       _clock = clock;

  DpapiJsonFileStore.applicationSupport()
    : this(directoryResolver: _applicationSupportPath);

  // 与 flutter_secure_storage_windows 同名同目录，升级、降级都读写同一个文件
  static const String fileName = 'flutter_secure_storage.dat';
  static const int maxCorruptBackups = 3;

  static const String _corruptMarker = '.corrupt-';
  static const String _temporarySuffix = '.tmp';
  static const String _logTag = 'SecureStorage';

  // 5：任何其他句柄开着目标都会拦下替换；32：对方独占打开；33：字节范围锁
  static const Set<int> _transientOsErrors = {5, 32, 33};

  static final Random _tokenSource = Random.secure();
  static final Random _jitterSource = Random();

  final Future<String> Function() _directoryResolver;
  final SecureBlobCipher _cipher;
  final SecureFileRetryPolicy _retryPolicy;
  final DateTime Function() _clock;

  Future<File>? _storageFile;

  static Future<String> _applicationSupportPath() async =>
      (await getApplicationSupportDirectory()).path;

  /// 文件不存在返回空表；损坏时改名留档后返回空表；读不到时抛出且不改动文件
  Future<Map<String, String>> load() => _load(_openWindow());

  /// 先写同目录临时文件再整体替换，失败时原文件保持原样
  Future<void> save(Map<String, String> data) => _save(data, _openWindow());

  /// 读改写共用一个重试期限；[mutate] 返回 false 表示内容未变、不必写回
  Future<void> update(bool Function(Map<String, String> data) mutate) async {
    final window = _openWindow();
    final data = await _load(window);
    if (!mutate(data)) return;
    await _save(data, window);
  }

  Future<void> clear() async {
    final window = _openWindow();
    final file = await _resolveStorageFile();
    await _withRetry(SecureStorageStep.deleteFile, window, () async {
      try {
        await file.delete();
      } on PathNotFoundException {
        return;
      }
    });
  }

  _RetryWindow _openWindow() => _RetryWindow(_retryPolicy.budget);

  Future<Map<String, String>> _load(_RetryWindow window) async {
    final file = await _resolveStorageFile();
    final bytes = await _withRetry(
      SecureStorageStep.readFile,
      window,
      () async {
        try {
          return await file.readAsBytes();
        } on PathNotFoundException {
          return null;
        }
      },
    );
    if (bytes == null) return <String, String>{};

    final decoded = _decode(bytes);
    if (decoded != null) return decoded;
    await _quarantine(file, window);
    return <String, String>{};
  }

  Future<void> _save(Map<String, String> data, _RetryWindow window) async {
    final file = await _resolveStorageFile();
    final encrypted = _encrypt(data);
    final temporary = File('${file.path}.${_randomToken()}$_temporarySuffix');
    try {
      await _withRetry(
        SecureStorageStep.writeFile,
        window,
        () => file.parent.create(recursive: true),
      );
      await _withRetry(
        SecureStorageStep.writeFile,
        window,
        () => temporary.writeAsBytes(encrypted, flush: true),
      );
      await _withRetry(
        SecureStorageStep.replaceFile,
        window,
        () => temporary.rename(file.path),
      );
    } catch (_) {
      await _discardTemporary(temporary);
      rethrow;
    }
  }

  Future<File> _resolveStorageFile() async {
    final pending = _storageFile ??= _locateStorageFile();
    try {
      return await pending;
    } catch (_) {
      if (identical(_storageFile, pending)) _storageFile = null;
      rethrow;
    }
  }

  Future<File> _locateStorageFile() async {
    final file = File(p.join(await _directoryResolver(), fileName));
    await _sweepStaleTemporaries(file);
    return file;
  }

  // 单实例互斥量保证同一时刻只有本进程写这个目录，首次访问时残留的临时文件都来自异常退出
  Future<void> _sweepStaleTemporaries(File file) async {
    final prefix = '${p.basename(file.path)}.';
    try {
      if (!await file.parent.exists()) return;
      await for (final entity in file.parent.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name.startsWith(prefix) &&
            name.endsWith(_temporarySuffix)) {
          await _discardTemporary(entity);
        }
      }
    } on FileSystemException catch (error) {
      AppLogger.w(
        'Stale secure storage temporaries not swept: '
        'os error ${error.osError?.errorCode}',
        _logTag,
      );
    }
  }

  Map<String, String>? _decode(Uint8List bytes) {
    final Uint8List plain;
    try {
      plain = _cipher.unprotect(bytes);
    } on DpapiException catch (error) {
      if (!error.corruptInput) {
        throw SecureStorageUnavailableException(
          SecureStorageStep.decrypt,
          osErrorCode: error.errorCode,
        );
      }
      AppLogger.w('Secure storage file cannot be decrypted: $error', _logTag);
      return null;
    }
    try {
      final Object? json = jsonDecode(utf8.decode(plain));
      if (json is! Map) {
        AppLogger.w('Secure storage file is not a JSON object', _logTag);
        return null;
      }
      return <String, String>{
        for (final entry in json.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      // FormatException 文本会带上解密后的原文，不能写进日志
      AppLogger.w('Secure storage file is not valid UTF-8 JSON', _logTag);
      return null;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  Uint8List _encrypt(Map<String, String> data) {
    final plain = utf8.encode(jsonEncode(data));
    try {
      return _cipher.protect(plain);
    } on DpapiException catch (error) {
      throw SecureStorageUnavailableException(
        SecureStorageStep.encrypt,
        osErrorCode: error.errorCode,
      );
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  Future<void> _quarantine(File file, _RetryWindow window) async {
    final backup = await _uniqueBackupFile(file);
    await _withRetry(SecureStorageStep.quarantineFile, window, () async {
      try {
        await file.rename(backup.path);
      } on PathNotFoundException {
        return;
      }
    });
    AppLogger.w(
      'Corrupt secure storage file moved to ${p.basename(backup.path)}',
      _logTag,
    );
    await _pruneCorruptBackups(file);
  }

  Future<File> _uniqueBackupFile(File file) async {
    final base = '${file.path}$_corruptMarker${_timestamp(_clock())}';
    var candidate = File(base);
    for (var suffix = 1; await candidate.exists(); suffix++) {
      candidate = File('$base-$suffix');
    }
    return candidate;
  }

  Future<void> _pruneCorruptBackups(File file) async {
    final prefix = '${p.basename(file.path)}$_corruptMarker';
    try {
      final backups = <File>[];
      await for (final entity in file.parent.list(followLinks: false)) {
        if (entity is File && p.basename(entity.path).startsWith(prefix)) {
          backups.add(entity);
        }
      }
      // 时间戳在文件名里且定宽，按名字倒序即新到旧
      backups.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      for (final stale in backups.skip(maxCorruptBackups)) {
        await stale.delete();
      }
    } on FileSystemException catch (error) {
      AppLogger.w(
        'Old corrupt secure storage backups not pruned: '
        'os error ${error.osError?.errorCode}',
        _logTag,
      );
    }
  }

  Future<void> _discardTemporary(File temporary) async {
    try {
      await temporary.delete();
    } on PathNotFoundException {
      return;
    } on FileSystemException catch (error) {
      AppLogger.w(
        'Secure storage temporary not removed: '
        'os error ${error.osError?.errorCode}',
        _logTag,
      );
    }
  }

  Future<T> _withRetry<T>(
    SecureStorageStep step,
    _RetryWindow window,
    Future<T> Function() action,
  ) async {
    var delay = _retryPolicy.initialDelay;
    while (true) {
      try {
        return await action();
      } on FileSystemException catch (error) {
        final code = error.osError?.errorCode;
        final wait = _jittered(delay);
        final retryable =
            code != null &&
            _transientOsErrors.contains(code) &&
            window.allows(wait);
        if (!retryable) {
          AppLogger.w(
            'Secure storage ${step.name} failed: os error $code',
            _logTag,
          );
          throw SecureStorageUnavailableException(step, osErrorCode: code);
        }
        await Future<void>.delayed(wait);
        final doubled = delay * 2;
        delay = doubled < _retryPolicy.maxDelay
            ? doubled
            : _retryPolicy.maxDelay;
      }
    }
  }

  Duration _jittered(Duration delay) {
    final spread = _retryPolicy.jitter;
    final factor = 1 - spread + _jitterSource.nextDouble() * spread * 2;
    return delay * factor;
  }

  static String _randomToken() => List<String>.generate(
    8,
    (_) => _tokenSource.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  static String _timestamp(DateTime time) {
    final utc = time.toUtc();
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    return '${pad(utc.year, 4)}${pad(utc.month, 2)}${pad(utc.day, 2)}T'
        '${pad(utc.hour, 2)}${pad(utc.minute, 2)}${pad(utc.second, 2)}'
        '${pad(utc.millisecond, 3)}Z';
  }
}

class _RetryWindow {
  _RetryWindow(this._budget) : _elapsed = Stopwatch()..start();

  final Duration _budget;
  final Stopwatch _elapsed;

  bool allows(Duration wait) => _elapsed.elapsed + wait <= _budget;
}
